import 'dart:typed_data';

/// Converts 16-, 32- or 128-bit Bluetooth UUIDs to the full lowercase form.
String normalizeBleUuid(String input) {
  var uuid = input.trim().toLowerCase();
  if (RegExp(r'^[0-9a-f]{4}$').hasMatch(uuid)) uuid = '0000$uuid';
  if (RegExp(r'^[0-9a-f]{8}$').hasMatch(uuid)) {
    uuid = '$uuid-0000-1000-8000-00805f9b34fb';
  }
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(uuid)) {
    throw ArgumentError.value(input, 'uuid', 'Invalid Bluetooth UUID');
  }
  return uuid;
}

class BleAdapterState {
  const BleAdapterState({
    required this.supported,
    required this.enabled,
    required this.permissionsGranted,
    required this.locationEnabled,
    required this.scanning,
    this.connectedDeviceId,
  });

  factory BleAdapterState.fromMap(Map<Object?, Object?> map) => BleAdapterState(
    supported: map['supported'] as bool,
    enabled: map['enabled'] as bool,
    permissionsGranted: map['permissionsGranted'] as bool,
    locationEnabled: map['locationEnabled'] as bool,
    scanning: map['scanning'] as bool,
    connectedDeviceId: map['connectedDeviceId'] as String?,
  );

  final bool supported;
  final bool enabled;
  final bool permissionsGranted;
  /// On Android 6–11, location services must be enabled to scan.
  /// On Android 12+ this is always true (neverForLocation scan mode).
  final bool locationEnabled;
  final bool scanning;
  final String? connectedDeviceId;
}

class BlePermissionResult {
  const BlePermissionResult({
    required this.granted,
    required this.deniedPermissions,
  });

  factory BlePermissionResult.fromMap(Map<Object?, Object?> map) =>
      BlePermissionResult(
        granted: map['granted'] as bool,
        deniedPermissions: List<String>.from(map['deniedPermissions'] as List),
      );

  final bool granted;
  final List<String> deniedPermissions;
}

class BleDevice {
  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.serviceUuids,
  });

  factory BleDevice.fromMap(Map<Object?, Object?> map) => BleDevice(
    id: map['id'] as String,
    name: map['name'] as String,
    rssi: map['rssi'] as int,
    serviceUuids: List<String>.from(map['serviceUuids'] as List),
  );

  final String id;
  final String name;
  final int rssi;
  final List<String> serviceUuids;
}

class BleCharacteristic {
  const BleCharacteristic({
    required this.uuid,
    required this.canRead,
    required this.canWrite,
    required this.canWriteWithoutResponse,
    required this.canNotify,
    required this.canIndicate,
  });

  factory BleCharacteristic.fromMap(Map<Object?, Object?> map) =>
      BleCharacteristic(
        uuid: map['uuid'] as String,
        canRead: map['read'] as bool,
        canWrite: map['write'] as bool,
        canWriteWithoutResponse: map['writeWithoutResponse'] as bool,
        canNotify: map['notify'] as bool,
        canIndicate: map['indicate'] as bool,
      );

  final String uuid;
  final bool canRead;
  final bool canWrite;
  final bool canWriteWithoutResponse;
  final bool canNotify;
  final bool canIndicate;
}

class BleService {
  const BleService({required this.uuid, required this.characteristics});

  factory BleService.fromMap(Map<Object?, Object?> map) => BleService(
    uuid: map['uuid'] as String,
    characteristics: (map['characteristics'] as List)
        .map(
          (e) => BleCharacteristic.fromMap(Map<Object?, Object?>.from(e as Map)),
        )
        .toList(growable: false),
  );

  final String uuid;
  final List<BleCharacteristic> characteristics;
}

enum BleConnectionState { connecting, connected, disconnected }

sealed class BleEvent {
  const BleEvent();

  factory BleEvent.fromMap(Map<Object?, Object?> map) {
    switch (map['type']) {
      case 'adapterState':
        return BleAdapterEvent(BleAdapterState.fromMap(map));
      case 'scanResult':
        return BleScanResultEvent(BleDevice.fromMap(map));
      case 'scanState':
        return BleScanStateEvent(map['scanning'] as bool);
      case 'connection':
        return BleConnectionEvent(
          deviceId: map['deviceId'] as String,
          state: BleConnectionState.values.byName(map['state'] as String),
          status: map['status'] as int,
        );
      case 'notification':
        return BleNotificationEvent(
          deviceId: map['deviceId'] as String,
          serviceUuid: map['serviceUuid'] as String,
          characteristicUuid: map['characteristicUuid'] as String,
          value: map['value'] as Uint8List,
        );
      case 'error':
        return BleErrorEvent(map['code'] as String, map['message'] as String);
      default:
        throw FormatException('Unknown Blooted event: ${map['type']}');
    }
  }
}

class BleAdapterEvent extends BleEvent {
  const BleAdapterEvent(this.state);
  final BleAdapterState state;
}

class BleScanResultEvent extends BleEvent {
  const BleScanResultEvent(this.device);
  final BleDevice device;
}

class BleScanStateEvent extends BleEvent {
  const BleScanStateEvent(this.scanning);
  final bool scanning;
}

class BleConnectionEvent extends BleEvent {
  const BleConnectionEvent({
    required this.deviceId,
    required this.state,
    required this.status,
  });
  final String deviceId;
  final BleConnectionState state;
  /// Android GATT status. Zero means success, -1 means local cancellation.
  final int status;
}

class BleNotificationEvent extends BleEvent {
  const BleNotificationEvent({
    required this.deviceId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.value,
  });
  final String deviceId;
  final String serviceUuid;
  final String characteristicUuid;
  final Uint8List value;
}

class BleErrorEvent extends BleEvent {
  const BleErrorEvent(this.code, this.message);
  final String code;
  final String message;
}
