import 'package:device_identity/device_identity.dart';
import 'package:device_identity/device_identity_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDevicePlatform extends DeviceIdentityPlatform {
  final methods = <String>[];
  Object? response;

  @override
  Future<Object?> invoke(String method) async {
    methods.add(method);
    return response;
  }
}

void main() {
  test('constructing the package does not read device identifiers', () {
    final platform = FakeDevicePlatform();
    DeviceIdentity(platform: platform);
    expect(platform.methods, isEmpty);
  });

  test('parses device details without reading IMEI', () async {
    final platform = FakeDevicePlatform()
      ..response = {
        'manufacturer': 'Test manufacturer',
        'brand': 'Test brand',
        'model': 'Test model',
        'device': 'test_device',
        'product': 'test_product',
        'hardware': 'test_hardware',
        'androidVersion': '15',
        'sdkInt': 35,
        'securityPatch': null,
        'supportedAbis': ['arm64-v8a'],
        'totalRamBytes': 4294967296,
        'totalStorageBytes': 68719476736,
        'availableStorageBytes': 34359738368,
        'hasTelephony': true,
      };
    final details = await DeviceIdentity(platform: platform).getDeviceInfo();
    expect(details.model, 'Test model');
    expect(details.totalRamBytes, 4294967296);
    expect(details.securityPatch, isNull);
    expect(platform.methods, ['getDeviceInfo']);
  });

  test('restricted IMEI remains absent, never substituted with another ID', () async {
    final platform = FakeDevicePlatform()
      ..response = {
        'status': 'restricted',
        'message': 'Android restriction',
        'entries': [
          {'slotIndex': 0, 'status': 'restricted', 'message': 'Restricted', 'imei': null},
        ],
      };
    final result = await DeviceIdentity(platform: platform).getImei();
    expect(result.status, ImeiStatus.restricted);
    expect(result.entries.single.imei, isNull);
    expect(platform.methods, ['getImei']);
  });

  test('parses multiple modem slots with partial availability', () {
    final result = ImeiReport.fromMap({
      'status': 'available',
      'message': 'Test response',
      'entries': [
        {'slotIndex': 0, 'status': 'available', 'message': 'Test only', 'imei': 'test-only'},
        {'slotIndex': 1, 'status': 'unavailable', 'message': 'No IMEI', 'imei': null},
      ],
    });
    expect(result.entries.length, 2);
    expect(result.entries.first.imei, 'test-only');
    expect(result.entries.last.status, ImeiStatus.unavailable);
  });

  test('permission status is explicit', () async {
    final platform = FakeDevicePlatform()
      ..response = {'status': 'denied', 'message': 'Denied by user'};
    final result = await DeviceIdentity(platform: platform).requestPhonePermission();
    expect(result.status, PhonePermissionStatus.denied);
    expect(platform.methods, ['requestPhonePermission']);
  });

  test('malformed native response fails explicitly', () async {
    final platform = FakeDevicePlatform()..response = 'not a map';
    await expectLater(
      DeviceIdentity(platform: platform).getDeviceInfo(),
      throwsStateError,
    );
  });
}
