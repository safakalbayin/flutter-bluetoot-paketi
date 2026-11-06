package dev.deviceidentity.device_identity

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.TelephonyManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.*
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Only invented test values are ever returned by the mocked phone service. */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [23, 24, 25, 26, 27, 28, 29, 30, 35])
@Suppress("DEPRECATION")
class DeviceIdentityPluginTest {
    private lateinit var context: Context
    private lateinit var manager: TelephonyManager
    private lateinit var packages: PackageManager
    private lateinit var plugin: DeviceIdentityPlugin
    private lateinit var binding: ActivityPluginBinding
    private lateinit var activity: Activity
    private lateinit var engine: FlutterPlugin.FlutterPluginBinding

    @Before fun setUp() {
        context = mock(Context::class.java)
        manager = mock(TelephonyManager::class.java)
        packages = mock(PackageManager::class.java)
        activity = mock(Activity::class.java)
        binding = mock(ActivityPluginBinding::class.java)
        engine = mock(FlutterPlugin.FlutterPluginBinding::class.java)
        `when`(engine.applicationContext).thenReturn(context)
        `when`(engine.binaryMessenger).thenReturn(mock(BinaryMessenger::class.java))
        `when`(context.packageManager).thenReturn(packages)
        `when`(packages.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)).thenReturn(true)
        `when`(context.checkSelfPermission(Manifest.permission.READ_PHONE_STATE))
            .thenReturn(PackageManager.PERMISSION_DENIED)
        `when`(context.getSystemService(Context.TELEPHONY_SERVICE)).thenReturn(manager)
        `when`(binding.activity).thenReturn(activity)
        `when`(manager.phoneCount).thenReturn(1)
        `when`(manager.phoneType).thenReturn(TelephonyManager.PHONE_TYPE_GSM)
        plugin = DeviceIdentityPlugin()
        plugin.onAttachedToEngine(engine)
        plugin.onAttachedToActivity(binding)
    }

    private fun grant() {
        `when`(context.checkSelfPermission(Manifest.permission.READ_PHONE_STATE))
            .thenReturn(PackageManager.PERMISSION_GRANTED)
    }

    private fun invoke(method: String): Reply = Reply().also {
        plugin.onMethodCall(MethodCall(method, null), it)
    }

    private fun requestCode(): Int {
        val code = ArgumentCaptor.forClass(Int::class.javaObjectType)
        verify(activity).requestPermissions(
            eq(arrayOf(Manifest.permission.READ_PHONE_STATE)), code.capture())
        return code.value
    }

    @Test fun permissionGateAndOsRestrictionDoNotPromptUnnecessarily() {
        val reply = invoke("requestPhonePermission")
        if (Build.VERSION.SDK_INT >= 29) {
            reply.assertStatus("restricted")
            verifyNoInteractions(activity, manager)
        } else {
            assertEquals(0, reply.completions)
            requestCode()
            assertTrue(plugin.onRequestPermissionsResult(requestCode(),
                arrayOf(Manifest.permission.READ_PHONE_STATE),
                intArrayOf(PackageManager.PERMISSION_DENIED)))
            reply.assertStatus("denied")
            invoke("getImei").assertStatus("permissionRequired")
            verifyNoInteractions(manager)
        }
    }

    @Test @Config(sdk = [23, 24, 25, 26, 27, 28])
    fun permissionGrantAndAlreadyGrantedCompleteExactlyOnce() {
        val reply = invoke("requestPhonePermission")
        val code = requestCode()
        grant()
        plugin.onRequestPermissionsResult(code, arrayOf(Manifest.permission.READ_PHONE_STATE),
            intArrayOf(PackageManager.PERMISSION_GRANTED))
        reply.assertStatus("granted")
        plugin.onRequestPermissionsResult(code, emptyArray(), intArrayOf())
        assertEquals(1, reply.completions)
        invoke("requestPhonePermission").assertStatus("granted")
        verify(activity, times(1)).requestPermissions(any(), anyInt())
    }

    @Test @Config(sdk = [23, 24, 25, 26, 27, 28])
    fun cancellationAndUnrelatedCallbacksDoNotLosePendingRequest() {
        val reply = invoke("requestPhonePermission")
        val code = requestCode()
        assertFalse(plugin.onRequestPermissionsResult(code + 1, emptyArray(), intArrayOf()))
        assertEquals(0, reply.completions)
        invoke("requestPhonePermission").assertError("busy")
        plugin.onRequestPermissionsResult(code, emptyArray(), intArrayOf())
        reply.assertStatus("denied")
        val retry = invoke("requestPhonePermission")
        assertEquals(0, retry.completions)
        plugin.onRequestPermissionsResult(code, emptyArray(), intArrayOf())
        retry.assertStatus("denied")
    }

    @Test @Config(sdk = [23, 24, 25, 26, 27, 28])
    fun rotationPreservesRequestAndRegistersOnlyNewActivityListener() {
        val reply = invoke("requestPhonePermission")
        val code = requestCode()
        plugin.onDetachedFromActivityForConfigChanges()
        verify(binding).removeRequestPermissionsResultListener(plugin)
        assertEquals(0, reply.completions)
        val next = mock(ActivityPluginBinding::class.java)
        plugin.onReattachedToActivityForConfigChanges(next)
        verify(next).addRequestPermissionsResultListener(plugin)
        invoke("requestPhonePermission").assertError("busy")
        grant()
        plugin.onRequestPermissionsResult(code, arrayOf(Manifest.permission.READ_PHONE_STATE),
            intArrayOf(PackageManager.PERMISSION_GRANTED))
        reply.assertStatus("granted")
        verify(activity, times(1)).requestPermissions(any(), anyInt())
        plugin.onDetachedFromActivity()
        verify(next).removeRequestPermissionsResultListener(plugin)
        assertEquals(1, reply.completions)
    }

    @Test @Config(sdk = [23, 24, 25, 26, 27, 28])
    fun permanentDetachAndEngineDetachResolvePendingReply() {
        val reply = invoke("requestPhonePermission")
        val code = requestCode()
        plugin.onDetachedFromActivity()
        reply.assertError("activity_detached")
        plugin.onRequestPermissionsResult(code, emptyArray(), intArrayOf())
        assertEquals(1, reply.completions)
        invoke("requestPhonePermission").assertError("no_activity")
        plugin.onAttachedToActivity(binding)
        val pending = invoke("requestPhonePermission")
        plugin.onDetachedFromActivityForConfigChanges()
        plugin.onDetachedFromEngine(engine)
        pending.assertError("activity_detached")
    }

    @Test @Config(sdk = [23, 28])
    fun dialogFailureIsSanitizedAndDoesNotLeaveBusyState() {
        doThrow(IllegalStateException("SENSITIVE_TEST_MARKER"))
            .`when`(activity).requestPermissions(any(), anyInt())
        invoke("requestPhonePermission").assertError("permission_request_failed")
        doNothing().`when`(activity).requestPermissions(any(), anyInt())
        assertEquals(0, invoke("requestPhonePermission").completions)
    }

    @Test fun deviceWithoutModemNeverRequestsPermissionOrReadsIdentifiers() {
        `when`(packages.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)).thenReturn(false)
        invoke("requestPhonePermission").assertStatus("notRequired")
        val reply = invoke("getImei")
        reply.assertStatus("noTelephony")
        assertTrue(reply.entries().isEmpty())
        verifyNoInteractions(activity, manager)
    }

    @Test fun systemSecurityExceptionBecomesStatusWithoutLeakingDetails() {
        grant()
        `when`(manager.getImei(anyInt())).thenThrow(SecurityException("SENSITIVE_TEST_MARKER"))
        `when`(manager.deviceId).thenThrow(SecurityException("SENSITIVE_TEST_MARKER"))
        val reply = invoke("getImei")
        reply.assertStatus(if (Build.VERSION.SDK_INT >= 29) "restricted" else "permissionRequired")
        assertFalse(reply.value.toString().contains("SENSITIVE_TEST_MARKER"))
        assertTrue(reply.entries().all { it["imei"] == null })
    }

    @Test @Config(sdk = [26, 28, 29, 30, 35])
    fun modemCountSecurityExceptionIsAlsoSanitized() {
        grant()
        `when`(manager.phoneCount).thenThrow(SecurityException("SENSITIVE_TEST_MARKER"))
        val reply = invoke("getImei")
        reply.assertStatus(if (Build.VERSION.SDK_INT >= 29) "restricted" else "permissionRequired")
        assertTrue(reply.entries().isEmpty())
        assertFalse(reply.value.toString().contains("SENSITIVE_TEST_MARKER"))
    }

    @Test @Config(sdk = [26, 27, 28, 29, 30, 35])
    fun multipleModemsKeepSlotIndexesAndPartialResults() {
        grant()
        `when`(manager.phoneCount).thenReturn(3)
        `when`(manager.getImei(0)).thenReturn(SYNTHETIC_IMEI)
        `when`(manager.getImei(1)).thenThrow(SecurityException("SENSITIVE_TEST_MARKER"))
        `when`(manager.getImei(2)).thenReturn(null)
        val reply = invoke("getImei")
        reply.assertStatus("available")
        val entries = reply.entries()
        assertEquals(listOf(0, 1, 2), entries.map { it["slotIndex"] })
        // Boolean comparison avoids printing even synthetic identifiers on failure.
        assertTrue(entries[0]["imei"] == SYNTHETIC_IMEI)
        assertEquals(if (Build.VERSION.SDK_INT >= 29) "restricted" else "permissionRequired",
            entries[1]["status"])
        assertNull(entries[1]["imei"])
        assertEquals("unavailable", entries[2]["status"])
        verify(manager).getImei(0)
        verify(manager).getImei(1)
        verify(manager).getImei(2)
        verify(manager, never()).getImei(3)
    }

    @Test fun malformedAndPlaceholderIdentifiersAreNeverReportedAsAvailable() {
        grant()
        for (raw in listOf(null, "", "000000000000000", "invalid", "1234")) {
            `when`(manager.getImei(anyInt())).thenReturn(raw)
            `when`(manager.deviceId).thenReturn(raw)
            val reply = invoke("getImei")
            reply.assertStatus("unavailable")
            assertTrue(reply.entries().all { it["imei"] == null })
        }
    }

    @Test fun unsupportedModemApiAndMissingPhoneServiceAreUnavailable() {
        grant()
        `when`(manager.getImei(anyInt())).thenThrow(UnsupportedOperationException())
        `when`(manager.deviceId).thenThrow(UnsupportedOperationException())
        invoke("getImei").assertStatus("unavailable")
        `when`(context.getSystemService(Context.TELEPHONY_SERVICE)).thenReturn(null)
        invoke("getImei").assertStatus("unavailable")
    }

    @Test @Config(sdk = [23, 24, 25])
    fun legacyGsmReadsOnlyOnExplicitCallAndCdmaIsNotMislabelledAsImei() {
        grant()
        invoke("requestPhonePermission").assertStatus("granted")
        verify(manager, never()).getDeviceId()
        `when`(manager.deviceId).thenReturn(SYNTHETIC_IMEI)
        val reply = invoke("getImei")
        reply.assertStatus("available")
        assertTrue(reply.entries().single()["imei"] == SYNTHETIC_IMEI)
        clearInvocations(manager)
        `when`(manager.phoneType).thenReturn(TelephonyManager.PHONE_TYPE_CDMA)
        invoke("getImei").assertStatus("unavailable")
        verify(manager, never()).getDeviceId()
        verify(manager, never()).getImei(anyInt())
    }

    @Test fun unexpectedErrorsUseGenericChannelError() {
        `when`(packages.hasSystemFeature(anyString()))
            .thenThrow(IllegalStateException("SENSITIVE_TEST_MARKER"))
        invoke("getImei").assertError("device_info_error")
    }

    private class Reply : MethodChannel.Result {
        var completions = 0
        var value: Any? = null
        var code: String? = null
        override fun success(result: Any?) { completions++; value = result }
        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            completions++
            code = errorCode
            assertFalse(errorMessage.orEmpty().contains("SENSITIVE_TEST_MARKER"))
            assertNull(errorDetails)
        }
        override fun notImplemented() { fail("Unexpected unimplemented method") }
        fun assertStatus(expected: String) {
            assertEquals(1, completions)
            assertNull(code)
            assertEquals(expected, (value as Map<*, *>)["status"])
        }
        fun assertError(expected: String) {
            assertEquals(1, completions)
            assertEquals(expected, code)
        }
        @Suppress("UNCHECKED_CAST")
        fun entries() = (value as Map<*, *>)["entries"] as List<Map<String, Any?>>
    }

    companion object {
        // Invented fixture; never sourced from a device.
        private const val SYNTHETIC_IMEI = "123456789012345"
    }
}
