import 'dart:typed_data';

import 'package:blooted/blooted.dart';
import 'package:blooted/blooted_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingPlatform extends BlootedPlatform {
  String? method;
  Map<String, Object?>? arguments;
  Object? response;

  @override
  Stream<Map<Object?, Object?>> get events => const Stream.empty();

  @override
  Future<Object?> invoke(String method, [Map<String, Object?>? arguments]) async {
    this.method = method;
    this.arguments = arguments;
    return response;
  }
}

void main() {
  test('normalizes short and full Bluetooth UUIDs', () {
    expect(normalizeBleUuid('180F'), '0000180f-0000-1000-8000-00805f9b34fb');
    expect(normalizeBleUuid('12345678'), '12345678-0000-1000-8000-00805f9b34fb');
    expect(
      normalizeBleUuid(' 00002A19-0000-1000-8000-00805F9B34FB '),
      '00002a19-0000-1000-8000-00805f9b34fb',
    );
    expect(() => normalizeBleUuid('invalid'), throwsArgumentError);
  });

  test('scan forwards native timeout and normalized service filters', () async {
    final platform = RecordingPlatform();
    await Blooted(platform: platform).startScan(serviceUuids: ['180F']);
    expect(platform.method, 'startScan');
    expect(platform.arguments, {
      'serviceUuids': ['0000180f-0000-1000-8000-00805f9b34fb'],
      'timeoutMs': 10000,
    });
  });

  test('rejects invalid address and timeout before native calls', () async {
    final platform = RecordingPlatform();
    final ble = Blooted(platform: platform);
    await expectLater(ble.connect('invalid'), throwsArgumentError);
    await expectLater(
      ble.startScan(timeout: const Duration(milliseconds: 100)),
      throwsArgumentError,
    );
    expect(platform.method, isNull);
  });

  test('write forwards raw bytes and response mode', () async {
    final platform = RecordingPlatform();
    final bytes = Uint8List.fromList([1, 160]);
    await Blooted(platform: platform).write(
      serviceUuid: '180F',
      characteristicUuid: '2A19',
      value: bytes,
      withResponse: false,
    );
    expect(platform.method, 'write');
    expect(platform.arguments!['value'], bytes);
    expect(platform.arguments!['withResponse'], false);
    expect(
      platform.arguments!['characteristicUuid'],
      '00002a19-0000-1000-8000-00805f9b34fb',
    );
  });

  test('write validates ATT payload length', () async {
    final platform = RecordingPlatform();
    final ble = Blooted(platform: platform);
    for (final size in [0, 21]) {
      await expectLater(
        ble.write(serviceUuid: '180F', characteristicUuid: '2A19', value: Uint8List(size)),
        throwsArgumentError,
      );
    }
    expect(platform.method, isNull);
  });

  test('parses adapter and permission responses', () async {
    final platform = RecordingPlatform()
      ..response = {
        'supported': true,
        'enabled': true,
        'permissionsGranted': true,
        'locationEnabled': true,
        'scanning': false,
        'connectedDeviceId': 'AA:BB:CC:DD:EE:FF',
      };
    final ble = Blooted(platform: platform);
    final state = await ble.getState();
    expect(state.connectedDeviceId, 'AA:BB:CC:DD:EE:FF');
    platform.response = {'granted': false, 'deniedPermissions': ['scan']};
    final permissions = await ble.requestPermissions();
    expect(permissions.granted, false);
    expect(permissions.deniedPermissions, ['scan']);
  });

  test('decodes notification bytes and connection states', () {
    final event = BleEvent.fromMap({
      'type': 'notification',
      'deviceId': 'AA:BB:CC:DD:EE:FF',
      'serviceUuid': 'service',
      'characteristicUuid': 'characteristic',
      'value': Uint8List.fromList([0, 255]),
    }) as BleNotificationEvent;
    expect(event.value, [0, 255]);
    final connection = BleEvent.fromMap({
      'type': 'connection',
      'deviceId': 'AA:BB:CC:DD:EE:FF',
      'state': 'disconnected',
      'status': 133,
    }) as BleConnectionEvent;
    expect(connection.state, BleConnectionState.disconnected);
    expect(connection.status, 133);
    expect(() => BleEvent.fromMap({'type': 'unknown'}), throwsFormatException);
  });

  test('decodes discovered characteristic properties', () async {
    final platform = RecordingPlatform()
      ..response = [
        {
          'uuid': 'service',
          'characteristics': [
            {
              'uuid': 'characteristic',
              'read': true,
              'write': false,
              'writeWithoutResponse': true,
              'notify': false,
              'indicate': true,
            },
          ],
        },
      ];
    final services = await Blooted(platform: platform).discoverServices();
    final characteristic = services.single.characteristics.single;
    expect(characteristic.canRead, true);
    expect(characteristic.canWrite, false);
    expect(characteristic.canIndicate, true);
  });
}
