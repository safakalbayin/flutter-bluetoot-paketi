import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_identity_method_channel.dart';

abstract class DeviceIdentityPlatform extends PlatformInterface {
  DeviceIdentityPlatform() : super(token: _token);

  static final Object _token = Object();
  static DeviceIdentityPlatform _instance = MethodChannelDeviceIdentity();

  static DeviceIdentityPlatform get instance => _instance;
  static set instance(DeviceIdentityPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Object?> invoke(String method);
}
