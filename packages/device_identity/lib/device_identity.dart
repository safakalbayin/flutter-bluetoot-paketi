/// Android device information and explicitly requested IMEI access.
library;

import 'device_identity_platform_interface.dart';
import 'src/models.dart';

export 'src/models.dart';

/// App-controlled access to Android device information.
///
/// No identifiers are collected automatically, persisted, logged or uploaded.
/// IMEI access is normally restricted on Android 10 and newer.
class DeviceIdentity {
  DeviceIdentity({DeviceIdentityPlatform? platform})
    : _platform = platform ?? DeviceIdentityPlatform.instance;

  final DeviceIdentityPlatform _platform;

  /// Public hardware / OS details. Does not require phone permission.
  Future<AndroidDeviceDetails> getDeviceInfo() async =>
      AndroidDeviceDetails.fromMap(await _invoke('getDeviceInfo'));

  /// Only prompts on Android 6–9. Android 10+ reports a restriction instead
  /// of requesting a permission that cannot grant ordinary apps IMEI access.
  Future<PhonePermissionResult> requestPhonePermission() async =>
      PhonePermissionResult.fromMap(await _invoke('requestPhonePermission'));

  /// Reads IMEI when Android permits it. Does not open permission dialogs.
  ///
  /// The result explains permission requirements, OS restrictions and devices
  /// without a modem. This is NOT an Android ID, serial number or generated ID.
  Future<ImeiReport> getImei() async =>
      ImeiReport.fromMap(await _invoke('getImei'));

  Future<Map<Object?, Object?>> _invoke(String method) async {
    final response = await _platform.invoke(method);
    if (response is! Map) {
      throw StateError('Invalid $method response from Android');
    }
    return Map<Object?, Object?>.from(response);
  }
}
