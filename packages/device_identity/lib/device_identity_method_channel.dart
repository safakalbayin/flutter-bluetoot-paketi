import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_identity_platform_interface.dart';

class MethodChannelDeviceIdentity extends DeviceIdentityPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('dev.deviceidentity/methods');

  @override
  Future<Object?> invoke(String method) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('DeviceIdentity supports Android only.');
    }
    return methodChannel.invokeMethod<Object?>(method);
  }
}
