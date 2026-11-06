package dev.deviceidentity.device_identity

import android.Manifest
import android.annotation.SuppressLint
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.StatFs
import android.telephony.TelephonyManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** No background collection, persistence, logging or network transmission. */
class DeviceIdentityPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activityBinding: ActivityPluginBinding? = null
    private var permissionReply: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dev.deviceidentity/methods")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detachActivity()
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        permissionReply?.error("activity_detached", "Activity closed during permission request", null)
        permissionReply = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getDeviceInfo" -> result.success(deviceInfo())
                "getImei" -> result.success(imeiReport())
                "requestPhonePermission" -> requestPermission(result)
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            // Do not expose native exception messages that might contain identifiers.
            result.error("device_info_error", "Android device information could not be read", null)
        }
    }

    private fun hasTelephony(): Boolean =
        context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)

    private fun deviceInfo(): Map<String, Any?> {
        val memory = ActivityManager.MemoryInfo()
        (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(memory)
        val storage = StatFs(context.filesDir.absolutePath)
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "hardware" to Build.HARDWARE,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "securityPatch" to if (Build.VERSION.SDK_INT >= 23) Build.VERSION.SECURITY_PATCH else null,
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
            "totalRamBytes" to memory.totalMem,
            "totalStorageBytes" to storage.totalBytes,
            "availableStorageBytes" to storage.availableBytes,
            "hasTelephony" to hasTelephony()
        )
    }

    private fun hasPhonePermission(): Boolean = Build.VERSION.SDK_INT < 23 ||
        context.checkSelfPermission(Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED

    private fun permissionState(): Map<String, Any> = when {
        !hasTelephony() -> mapOf("status" to "notRequired",
            "message" to "Bu cihazda telefon modemi yok.")
        Build.VERSION.SDK_INT >= 29 -> mapOf("status" to "restricted",
            "message" to RESTRICTED_MESSAGE)
        hasPhonePermission() -> mapOf("status" to "granted",
            "message" to "Telefon durumu izni verildi.")
        else -> mapOf("status" to "denied",
            "message" to "Telefon durumu izni verilmedi. Gerekirse Android uygulama ayarlarından izin verin.")
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (permissionReply != null) {
            result.error("busy", "A phone permission request is already pending", null)
            return
        }
        if (!hasTelephony() || Build.VERSION.SDK_INT >= 29 || hasPhonePermission()) {
            result.success(permissionState())
            return
        }
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("no_activity", "Permission prompts require a foreground Activity", null)
            return
        }
        permissionReply = result
        try {
            if (Build.VERSION.SDK_INT >= 23) {
                activity.requestPermissions(arrayOf(Manifest.permission.READ_PHONE_STATE), REQUEST_CODE)
            }
        } catch (_: Exception) {
            permissionReply = null
            result.error("permission_request_failed", "Phone permission dialog could not be opened", null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        permissionReply?.success(permissionState())
        permissionReply = null
        return true
    }

    @SuppressLint("MissingPermission", "HardwareIds")
    @Suppress("DEPRECATION")
    private fun imeiReport(): Map<String, Any?> {
        if (!hasTelephony()) {
            return report("noTelephony", "Bu cihazda telefon modemi yok; IMEI bulunmaz.")
        }
        if (Build.VERSION.SDK_INT < 29 && !hasPhonePermission()) {
            return report("permissionRequired", "IMEI okumak için önce telefon durumu izni verin.")
        }
        val manager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager?
            ?: return report("unavailable", "Android telefon servisi kullanılamıyor.")

        // Android 10+ restrictions are enforced by the OS. No reflection,
        // system-property lookup, serial/Android-ID substitution or bypass.
        val entries = mutableListOf<Map<String, Any?>>()
        val count = try {
            if (Build.VERSION.SDK_INT >= 26) manager.phoneCount.coerceAtLeast(1) else 1
        } catch (_: SecurityException) {
            return if (Build.VERSION.SDK_INT >= 29) report("restricted", RESTRICTED_MESSAGE)
                else report("permissionRequired", "Android modem bilgilerine erişimi reddetti.")
        }
        for (slot in 0 until count) {
            val entry = try {
                val raw = if (Build.VERSION.SDK_INT >= 26) {
                    manager.getImei(slot)
                } else if (manager.phoneType == TelephonyManager.PHONE_TYPE_GSM) {
                    manager.deviceId
                } else null // Legacy CDMA deviceId is a MEID, not an IMEI.
                // Do not show all-zero placeholders or malformed IDs as an IMEI.
                val valid = raw != null && raw.matches(Regex("[0-9]{15}")) &&
                    raw.any { it != '0' }
                if (valid) {
                    imeiEntry(slot, "available", "IMEI Android tarafından sağlandı.", raw)
                } else {
                    imeiEntry(slot, "unavailable", "Bu modem için geçerli bir IMEI sağlanmadı.", null)
                }
            } catch (_: SecurityException) {
                imeiEntry(slot,
                    if (Build.VERSION.SDK_INT >= 29) "restricted" else "permissionRequired",
                    if (Build.VERSION.SDK_INT >= 29) RESTRICTED_MESSAGE
                    else "Telefon izni eksik veya Android erişimi reddetti.", null)
            } catch (_: UnsupportedOperationException) {
                imeiEntry(slot, "unavailable", "Bu modem IMEI API'sini desteklemiyor.", null)
            }
            entries.add(entry)
        }
        val status = when {
            entries.any { it["status"] == "available" } -> "available"
            entries.any { it["status"] == "restricted" } -> "restricted"
            entries.any { it["status"] == "permissionRequired" } -> "permissionRequired"
            else -> "unavailable"
        }
        val message = when (status) {
            "available" -> "Erişime izin verilen modemlerin IMEI bilgileri aşağıdadır."
            "restricted" -> RESTRICTED_MESSAGE
            "permissionRequired" -> "Telefon durumu izni gerekli."
            else -> "Android bir IMEI döndürmedi. Cihazın Ayarlar > Telefon hakkında ekranını kontrol edin."
        }
        return report(status, message, entries)
    }

    private fun imeiEntry(slot: Int, status: String, message: String, value: String?) =
        mapOf("slotIndex" to slot, "status" to status, "message" to message, "imei" to value)

    private fun report(
        status: String, message: String, entries: List<Map<String, Any?>> = emptyList()
    ): Map<String, Any?> = mapOf("status" to status, "message" to message, "entries" to entries)

    companion object {
        private const val REQUEST_CODE = 46322
        private const val RESTRICTED_MESSAGE =
            "Android 10 ve sonrasında normal uygulamalar IMEI okuyamaz. " +
            "READ_PHONE_STATE izni tek başına yeterli değildir. " +
            "IMEI için cihazın Ayarlar > Telefon hakkında ekranına bakın."
    }
}
