import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'blooted_platform_interface.dart';

class MethodChannelBlooted extends BlootedPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('dev.blooted/methods');

  // One subscription to Android even if several Blooted handles are created.
  static final Stream<Map<Object?, Object?>> _nativeEvents =
      const EventChannel('dev.blooted/events')
          .receiveBroadcastStream()
          .map((event) => Map<Object?, Object?>.from(event as Map));

  @override
  Stream<Map<Object?, Object?>> get events => _nativeEvents;

  @override
  Future<Object?> invoke(String method, [Map<String, Object?>? arguments]) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Blooted currently supports Android BLE only.');
    }
    return methodChannel.invokeMethod<Object?>(method, arguments);
  }
}
