package dev.blooted.blooted

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.UUID

/**
 * One engine owns one scan and one connection. All mutable state and Flutter
 * replies are confined to the main looper; Android callbacks are marshalled here.
 */
@SuppressLint("MissingPermission")
class BlootedPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var permissionReply: MethodChannel.Result? = null
    private var scanner: BluetoothLeScanner? = null
    private var scanCallback: ScanCallback? = null
    private var scanTimer: Runnable? = null
    private var gatt: BluetoothGatt? = null
    private var deviceId: String? = null
    private var connected = false
    private var connectReply: MethodChannel.Result? = null
    private var connectTimer: Runnable? = null
    private var operation: GattOperation? = null

    private class GattOperation(
        val name: String,
        val reply: MethodChannel.Result,
        val timer: Runnable,
        val target: BluetoothGattCharacteristic?
    )

    private val adapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?)?.adapter

    private val stateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                if (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1) != BluetoothAdapter.STATE_ON) {
                    stopScan()
                    closeConnection("bluetooth_off", "Bluetooth turned off")
                }
            }
            emitState()
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "dev.blooted/methods")
        events = EventChannel(binding.binaryMessenger, "dev.blooted/events")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED).apply {
            addAction(LocationManager.MODE_CHANGED_ACTION)
        }
        // These are protected system broadcasts; EXPORTED is necessary for
        // Bluetooth broadcasts sent by the privileged Bluetooth process.
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(stateReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(stateReceiver, filter)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopScan()
        closeConnection("cancelled", "Flutter engine detached")
        detachActivity()
        context.unregisterReceiver(stateReceiver)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        sink = null
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        sink = eventSink
        emitState()
    }

    override fun onCancel(arguments: Any?) {
        sink = null // The app, not an event listener, owns the radio session.
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null // Keep permission reply across rotation.
    }

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        permissionReply?.error("activity_detached", "Activity detached during permission request", null)
        permissionReply = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        permissionReply?.success(permissionState())
        permissionReply = null
        emitState()
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getState" -> result.success(state())
                "requestPermissions" -> requestPermissions(result)
                "startScan" -> startScan(call, result)
                "stopScan" -> { stopScan(); result.success(null) }
                "connect" -> connect(call, result)
                "disconnect" -> {
                    closeConnection("cancelled", "Disconnected by app")
                    result.success(null)
                }
                "discoverServices", "read", "write", "setNotify" -> gattOperation(call, result)
                else -> result.notImplemented()
            }
        } catch (error: BleFailure) {
            result.error(error.code, error.message, null)
        } catch (error: SecurityException) {
            result.error("permission_denied", error.message, null)
        } catch (error: IllegalArgumentException) {
            result.error("invalid_argument", error.message, null)
        } catch (error: Exception) {
            result.error("native_error", error.message, null)
        }
    }

    private fun requiredPermissions(): List<String> = when {
        Build.VERSION.SDK_INT >= 31 ->
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        Build.VERSION.SDK_INT >= 23 -> listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        else -> emptyList()
    }

    private fun deniedPermissions(): List<String> = requiredPermissions().filter {
        Build.VERSION.SDK_INT >= 23 &&
            context.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
    }

    private fun permissionState(): Map<String, Any> {
        val denied = deniedPermissions()
        return mapOf("granted" to denied.isEmpty(), "deniedPermissions" to denied)
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (permissionReply != null) throw BleFailure("busy", "A permission request is already pending")
        val denied = deniedPermissions()
        if (denied.isEmpty()) { result.success(permissionState()); return }
        val activity: Activity = activityBinding?.activity
            ?: throw BleFailure("no_activity", "Permission prompts require a foreground Activity")
        permissionReply = result
        try {
            if (Build.VERSION.SDK_INT >= 23) {
                activity.requestPermissions(denied.toTypedArray(), PERMISSION_REQUEST)
            }
        } catch (error: Exception) {
            permissionReply = null
            throw error
        }
    }

    private fun locationEnabled(): Boolean {
        if (Build.VERSION.SDK_INT !in 23..30) return true
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    private fun state(): Map<String, Any?> {
        val permission = deniedPermissions().isEmpty()
        val enabled = try { adapter?.isEnabled == true } catch (_: SecurityException) { false }
        return mapOf(
            "supported" to (adapter != null &&
                context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)),
            "enabled" to enabled,
            "permissionsGranted" to permission,
            "locationEnabled" to locationEnabled(),
            "scanning" to (scanCallback != null),
            "connectedDeviceId" to if (connected) deviceId else null
        )
    }

    private fun requireReady() {
        if (adapter == null ||
            !context.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            throw BleFailure("unsupported", "This device does not support BLE")
        }
        if (deniedPermissions().isNotEmpty()) throw BleFailure("permission_denied", "Request Bluetooth permissions first")
        if (adapter?.isEnabled != true) throw BleFailure("bluetooth_off", "Enable Bluetooth in Android settings")
    }

    private fun startScan(call: MethodCall, result: MethodChannel.Result) {
        requireReady()
        if (!locationEnabled()) throw BleFailure("location_off", "Enable location services on Android 6–11")
        if (scanCallback != null) throw BleFailure("busy", "A scan is already running")
        val filters = (call.argument<List<String>>("serviceUuids") ?: emptyList()).map {
            ScanFilter.Builder().setServiceUuid(ParcelUuid(UUID.fromString(it))).build()
        }
        val timeout = timeout(call)
        val activeScanner = adapter?.bluetoothLeScanner
            ?: throw BleFailure("scanner_unavailable", "BLE scanner unavailable")
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                handler.post {
                    if (scanCallback !== this) return@post
                    emit(mapOf(
                        "type" to "scanResult",
                        "id" to scanResult.device.address,
                        "name" to (scanResult.scanRecord?.deviceName ?: ""),
                        "rssi" to scanResult.rssi,
                        "serviceUuids" to (scanResult.scanRecord?.serviceUuids?.map { it.toString() } ?: emptyList<String>())
                    ))
                }
            }
            override fun onScanFailed(errorCode: Int) {
                handler.post {
                    if (scanCallback !== this) return@post
                    stopScan()
                    emit(mapOf("type" to "error", "code" to "scan_failed",
                        "message" to "Android scan failed: $errorCode"))
                }
            }
        }
        scanner = activeScanner
        scanCallback = callback
        try {
            activeScanner.startScan(filters,
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(), callback)
        } catch (error: Exception) {
            scanner = null
            scanCallback = null
            throw error
        }
        scanTimer = Runnable { stopScan() }.also { handler.postDelayed(it, timeout) }
        emit(mapOf("type" to "scanState", "scanning" to true))
        result.success(null)
    }

    private fun stopScan() {
        scanTimer?.let { handler.removeCallbacks(it) }
        scanTimer = null
        val callback = scanCallback
        scanCallback = null
        if (callback != null) {
            try { scanner?.stopScan(callback) } catch (_: SecurityException) {
                // Permissions may have been revoked; local scan ownership still ends.
            } catch (_: IllegalStateException) { /* Radio already off. */ }
            emit(mapOf("type" to "scanState", "scanning" to false))
        }
        scanner = null
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        requireReady()
        if (gatt != null || connectReply != null) throw BleFailure("busy", "Disconnect the current device first")
        val id = requireNotNull(call.argument<String>("deviceId")) { "deviceId is required" }
        val wait = timeout(call)
        val device = adapter!!.getRemoteDevice(id)
        stopScan()
        deviceId = id
        connectReply = result
        emitConnection("connecting", 0)
        try {
            gatt = if (Build.VERSION.SDK_INT >= 23) {
                device.connectGatt(context, false, callbacks, android.bluetooth.BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(context, false, callbacks)
            }
            if (gatt == null) throw BleFailure("connect_failed", "Android could not create a GATT connection")
            connectTimer = Runnable {
                closeConnection("timeout", "Connection timed out")
            }.also { handler.postDelayed(it, wait) }
        } catch (error: Exception) {
            // connect() owns this reply already; do not let the outer handler reply twice.
            closeConnection("connect_failed", error.message ?: "Connection failed")
        }
    }

    private fun closeConnection(code: String, message: String, status: Int = -1) {
        connectTimer?.let { handler.removeCallbacks(it) }
        connectTimer = null
        connectReply?.error(code, message, null)
        connectReply = null
        finishOperation(errorCode = code, message = message)
        val oldGatt = gatt
        gatt = null
        connected = false
        if (deviceId != null) emitConnection("disconnected", status)
        deviceId = null
        try { oldGatt?.disconnect() } catch (_: SecurityException) { /* Revoked permission. */ }
        oldGatt?.close()
    }

    private fun gattOperation(call: MethodCall, result: MethodChannel.Result) {
        requireReady()
        val active = gatt
        if (!connected || active == null) throw BleFailure("not_connected", "Connect to a device first")
        if (operation != null) throw BleFailure("busy", "Await the previous GATT operation")
        val target = if (call.method == "discoverServices") null else {
            val serviceUuid = UUID.fromString(call.argument<String>("serviceUuid"))
            val characteristicUuid = UUID.fromString(call.argument<String>("characteristicUuid"))
            active.getService(serviceUuid)?.getCharacteristic(characteristicUuid)
                ?: throw BleFailure("not_found", "Discover services first; characteristic was not found")
        }
        // Validate everything before claiming the reply.
        val value = call.argument<ByteArray>("value")
        val withResponse = call.argument<Boolean>("withResponse") ?: true
        val enabled = call.argument<Boolean>("enabled") ?: false
        val descriptor = if (call.method == "setNotify") {
            requireProperty(target!!,
                BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_INDICATE)
            target.getDescriptor(CCCD)
                ?: throw BleFailure("not_found", "Characteristic has no CCCD (0x2902)")
        } else null
        when (call.method) {
            "read" -> requireProperty(target!!, BluetoothGattCharacteristic.PROPERTY_READ)
            "write" -> {
                requireProperty(target!!, if (withResponse) BluetoothGattCharacteristic.PROPERTY_WRITE
                    else BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE)
                if (value == null || value.isEmpty() || value.size > 20) {
                    throw BleFailure("invalid_argument", "Write payload must contain 1–20 bytes")
                }
            }
        }
        val timer = Runnable {
            // Never reuse this link after timeout: a late callback could otherwise
            // complete a later operation for the same UUID.
            closeConnection("timeout", "GATT operation timed out; reconnect before retrying")
        }
        operation = GattOperation(call.method, result, timer, target)
        handler.postDelayed(timer, 10000)
        try {
            val started = when (call.method) {
                "discoverServices" -> active.discoverServices()
                "read" -> active.readCharacteristic(target!!)
                "write" -> writeCharacteristic(active, target!!, value!!, withResponse)
                "setNotify" -> {
                    if (!active.setCharacteristicNotification(target!!, enabled)) {
                        false
                    } else {
                        val data = if (!enabled) BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                        else if (target.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0)
                            BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        else BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
                        writeDescriptor(active, descriptor!!, data)
                    }
                }
                else -> false
            }
            if (!started) finishOperation(errorCode = "operation_failed",
                message = "Android rejected ${call.method}")
        } catch (error: Exception) {
            finishOperation(errorCode = if (error is SecurityException) "permission_denied" else "native_error",
                message = error.message ?: "GATT operation failed")
        }
    }

    @Suppress("DEPRECATION")
    private fun writeCharacteristic(
        active: BluetoothGatt, target: BluetoothGattCharacteristic, data: ByteArray, withResponse: Boolean
    ): Boolean {
        val writeType = if (withResponse) BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            else BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        return if (Build.VERSION.SDK_INT >= 33) {
            active.writeCharacteristic(target, data, writeType) == BluetoothStatusCodes.SUCCESS
        } else {
            target.writeType = writeType
            target.value = data
            active.writeCharacteristic(target)
        }
    }

    @Suppress("DEPRECATION")
    private fun writeDescriptor(active: BluetoothGatt, target: BluetoothGattDescriptor, data: ByteArray): Boolean =
        if (Build.VERSION.SDK_INT >= 33) {
            active.writeDescriptor(target, data) == BluetoothStatusCodes.SUCCESS
        } else {
            target.value = data
            active.writeDescriptor(target)
        }

    private fun requireProperty(target: BluetoothGattCharacteristic, property: Int) {
        if (target.properties and property == 0) {
            throw BleFailure("not_supported", "Characteristic does not support this operation")
        }
    }

    private fun finishOperation(value: Any? = null, errorCode: String? = null, message: String = "") {
        val pending = operation ?: return
        operation = null
        handler.removeCallbacks(pending.timer)
        if (errorCode == null) pending.reply.success(value)
        else pending.reply.error(errorCode, message, null)
    }

    private fun completeCallback(
        source: BluetoothGatt, name: String, status: Int,
        characteristic: BluetoothGattCharacteristic? = null, value: Any? = null
    ) {
        if (gatt !== source || operation?.name != name) return
        if (characteristic != null && operation?.target !== characteristic) return
        if (status == BluetoothGatt.GATT_SUCCESS) finishOperation(value)
        else finishOperation(errorCode = "gatt_error", message = "$name failed with GATT status $status")
    }

    private val callbacks = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(source: BluetoothGatt, status: Int, newState: Int) {
            handler.post {
                if (gatt !== source) { source.close(); return@post }
                if (status != BluetoothGatt.GATT_SUCCESS || newState == BluetoothProfile.STATE_DISCONNECTED) {
                    closeConnection("disconnected", "Device disconnected (GATT $status)", status)
                } else if (newState == BluetoothProfile.STATE_CONNECTED) {
                    connectTimer?.let { handler.removeCallbacks(it) }
                    connectTimer = null
                    connected = true
                    emitConnection("connected", status)
                    connectReply?.success(null)
                    connectReply = null
                }
            }
        }

        override fun onServicesDiscovered(source: BluetoothGatt, status: Int) {
            handler.post {
                if (gatt !== source) return@post
                val services = source.services.map { service ->
                    mapOf("uuid" to service.uuid.toString(), "characteristics" to service.characteristics.map { c ->
                        mapOf(
                            "uuid" to c.uuid.toString(),
                            "read" to (c.properties and BluetoothGattCharacteristic.PROPERTY_READ != 0),
                            "write" to (c.properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0),
                            "writeWithoutResponse" to (c.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0),
                            "notify" to (c.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0),
                            "indicate" to (c.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0)
                        )
                    })
                }
                completeCallback(source, "discoverServices", status, value = services)
            }
        }

        @Deprecated("Legacy Android callback")
        @Suppress("DEPRECATION")
        override fun onCharacteristicRead(source: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
            if (Build.VERSION.SDK_INT < 33) {
                val data = c.value?.clone() ?: byteArrayOf()
                handler.post { completeCallback(source, "read", status, c, data) }
            }
        }

        override fun onCharacteristicRead(
            source: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray, status: Int
        ) {
            val data = value.clone()
            handler.post { completeCallback(source, "read", status, c, data) }
        }

        override fun onCharacteristicWrite(source: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
            handler.post { completeCallback(source, "write", status, c) }
        }

        override fun onDescriptorWrite(source: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            handler.post {
                if (descriptor.uuid == CCCD) {
                    completeCallback(source, "setNotify", status, descriptor.characteristic)
                }
            }
        }

        @Deprecated("Legacy Android callback")
        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(source: BluetoothGatt, c: BluetoothGattCharacteristic) {
            if (Build.VERSION.SDK_INT < 33) notify(source, c, c.value?.clone() ?: byteArrayOf())
        }

        override fun onCharacteristicChanged(source: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
            notify(source, c, value.clone())
        }
    }

    private fun notify(source: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
        handler.post {
            if (gatt !== source || !connected) return@post
            emit(mapOf("type" to "notification", "deviceId" to deviceId,
                "serviceUuid" to c.service.uuid.toString(), "characteristicUuid" to c.uuid.toString(),
                "value" to value))
        }
    }

    private fun timeout(call: MethodCall): Long {
        val millis = call.argument<Number>("timeoutMs")?.toLong() ?: 10000
        require(millis in 1000..120000) { "timeoutMs must be 1000–120000" }
        return millis
    }

    private fun emitState() = emit(state() + ("type" to "adapterState"))
    private fun emitConnection(state: String, status: Int) =
        emit(mapOf("type" to "connection", "deviceId" to deviceId, "state" to state, "status" to status))
    private fun emit(event: Map<String, Any?>) { sink?.success(event) }

    private class BleFailure(val code: String, message: String) : RuntimeException(message)

    companion object {
        private const val PERMISSION_REQUEST = 46321
        private val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
