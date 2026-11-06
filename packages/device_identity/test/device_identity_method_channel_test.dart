import 'package:device_identity/device_identity_method_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.deviceidentity/methods');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('forwards the exact native method without hidden collection', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return {'status': 'restricted', 'message': 'Restricted', 'entries': []};
    });
    final result = await MethodChannelDeviceIdentity().invoke('getImei');
    expect(result, isA<Map>());
    expect(calls, ['getImei']);
  });

  test('unsupported platforms fail before native dispatch', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      () => MethodChannelDeviceIdentity().invoke('getDeviceInfo'),
      throwsUnsupportedError,
    );
  });
}
