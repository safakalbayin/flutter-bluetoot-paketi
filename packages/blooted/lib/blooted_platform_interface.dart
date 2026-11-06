import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'blooted_method_channel.dart';

/// Replaceable transport boundary for another native platform or app tests.
abstract class BlootedPlatform extends PlatformInterface {
  BlootedPlatform() : super(token: _token);

  static final Object _token = Object();
  static BlootedPlatform _instance = MethodChannelBlooted();

  static BlootedPlatform get instance => _instance;
  static set instance(BlootedPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<Map<Object?, Object?>> get events;

  Future<Object?> invoke(String method, [Map<String, Object?>? arguments]);
}
