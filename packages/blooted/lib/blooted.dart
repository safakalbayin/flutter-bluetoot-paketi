/// Android BLE transport. The consuming app owns all connection policy.
library;

import 'dart:typed_data';

import 'blooted_platform_interface.dart';
import 'src/models.dart';

export 'src/models.dart';

/// A handle to the single native BLE session attached to the Flutter engine.
///
/// Subscribe to [events] before starting operations. Multiple handles share the
/// same radio, connection and broadcast stream. Cancel your subscriptions when
/// the screen is disposed, and explicitly [disconnect] when no longer needed.
/// No automatic scanning, permission prompts, pairing or reconnects occur.
class Blooted {
  Blooted({BlootedPlatform? platform})
    : _platform = platform ?? BlootedPlatform.instance;

  final BlootedPlatform _platform;
  late final Stream<BleEvent> _events = _platform.events.map(BleEvent.fromMap);

  Stream<BleEvent> get events => _events;

  Future<BleAdapterState> getState() async =>
      BleAdapterState.fromMap(await _map('getState'));

  /// Shows Android runtime permission prompts only when the app calls this.
  /// Inspect [BlePermissionResult.granted] before scanning or connecting.
  Future<BlePermissionResult> requestPermissions() async =>
      BlePermissionResult.fromMap(await _map('requestPermissions'));

  /// Scan for BLE advertisements, optionally filtered by full service UUIDs.
  /// Android stops automatically at [timeout] and emits a [BleScanStateEvent].
  Future<void> startScan({
    List<String> serviceUuids = const [],
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _timeout(timeout);
    await _platform.invoke('startScan', {
      'serviceUuids': serviceUuids.map(normalizeBleUuid).toList(),
      'timeoutMs': timeout.inMilliseconds,
    });
  }

  Future<void> stopScan() async => _platform.invoke('stopScan');

  /// Resolves when connected; service discovery is a separate app decision.
  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _timeout(timeout);
    if (!RegExp(r'^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$').hasMatch(deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Invalid Android address');
    }
    await _platform.invoke('connect', {
      'deviceId': deviceId,
      'timeoutMs': timeout.inMilliseconds,
    });
  }

  /// Cancels any pending operation and closes the current GATT connection.
  Future<void> disconnect() async => _platform.invoke('disconnect');

  Future<List<BleService>> discoverServices() async {
    final data = await _platform.invoke('discoverServices');
    if (data is! List) {
      throw StateError('Invalid discoverServices response from Android');
    }
    return data
        .map((e) => BleService.fromMap(Map<Object?, Object?>.from(e as Map)))
        .toList(growable: false);
  }

  Future<Uint8List> read({
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    final data = await _platform.invoke(
      'read',
      _target(serviceUuid, characteristicUuid),
    );
    if (data is! Uint8List) {
      throw StateError('Invalid read response from Android');
    }
    return data;
  }

  /// Sends one ATT payload (1–20 bytes), with no implicit chunking or protocol.
  /// For longer messages the app must define and send its own chunks.
  Future<void> write({
    required String serviceUuid,
    required String characteristicUuid,
    required Uint8List value,
    bool withResponse = true,
  }) async {
    if (value.isEmpty || value.length > 20) {
      throw ArgumentError.value(value.length, 'value.length', 'Expected 1–20');
    }
    await _platform.invoke('write', {
      ..._target(serviceUuid, characteristicUuid),
      'value': value,
      'withResponse': withResponse,
    });
  }

  /// Writes the CCCD and enables notifications (or indications if required).
  /// Values arrive through [BleNotificationEvent] on [events].
  Future<void> setNotify({
    required String serviceUuid,
    required String characteristicUuid,
    required bool enabled,
  }) async => _platform.invoke('setNotify', {
    ..._target(serviceUuid, characteristicUuid),
    'enabled': enabled,
  });

  Map<String, Object?> _target(String service, String characteristic) => {
    'serviceUuid': normalizeBleUuid(service),
    'characteristicUuid': normalizeBleUuid(characteristic),
  };

  void _timeout(Duration duration) {
    if (duration.inMilliseconds < 1000 || duration.inMilliseconds > 120000) {
      throw ArgumentError.value(duration, 'timeout', 'Expected 1–120 seconds');
    }
  }

  Future<Map<Object?, Object?>> _map(String method) async {
    final data = await _platform.invoke(method);
    if (data is! Map) throw StateError('Invalid $method response from Android');
    return Map<Object?, Object?>.from(data);
  }
}
