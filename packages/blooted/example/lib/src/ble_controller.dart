import 'dart:async';
import 'package:blooted/blooted.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Application policy lives here, not inside the package.
///
/// This example discovers services after manual connection, never reconnects
/// automatically, and closes the radio session when the app goes to background.
class BleController extends ChangeNotifier with WidgetsBindingObserver {
  final Blooted ble = Blooted();
  final Map<String, BleDevice> _devices = {};
  final Map<String, Uint8List> values = {};
  final Set<String> notifying = {};
  final List<String> logs = [];
  List<BleService> services = [];
  BleAdapterState? adapter;
  String? connectedId;
  String? error;
  bool scanning = false;
  bool busy = false;
  bool _disposed = false;
  StreamSubscription<BleEvent>? _subscription;

  bool get nativeAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  List<BleDevice> get devices =>
      _devices.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  String targetKey(String service, String characteristic) => '$service/$characteristic';

  void initialize() {
    // No permission dialog or scan until the user explicitly asks.
    if (!nativeAvailable) return;
    WidgetsBinding.instance.addObserver(this);
    _subscription = ble.events.listen(
      _onEvent,
      onError: (Object e) {
        error = e.toString();
        _log(error!);
        _changed();
      },
    );
    unawaited(refresh());
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _changed();
    try {
      await action();
    } catch (e) {
      error = e.toString();
      _log('Hata: $e');
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> refresh() => _run(() async {
    adapter = await ble.getState();
    scanning = adapter!.scanning;
    connectedId = adapter!.connectedDeviceId;
  });

  Future<void> requestPermissions() => _run(() async {
    final result = await ble.requestPermissions();
    _log(result.granted ? 'İzinler verildi.' : 'Reddedilen izinler: ${result.deniedPermissions.join(', ')}');
    if (!result.granted) {
      error = 'Bluetooth izni verilmedi. İzin penceresi açılmıyorsa Android uygulama ayarlarından izin verin.';
    }
    adapter = await ble.getState();
  });

  Future<void> scan() => _run(() async {
    _devices.clear();
    await ble.startScan();
    scanning = true;
    _log('10 saniyelik BLE taraması başlatıldı.');
  });

  Future<void> stopScan() => _run(() async {
    await ble.stopScan();
    scanning = false;
  });

  Future<void> connect(String id) => _run(() async {
    services = [];
    values.clear();
    notifying.clear();
    await ble.connect(id);
    connectedId = id;
    // This is an app choice; the package does not auto-discover services.
    services = await ble.discoverServices();
    _log('${services.length} servis bulundu.');
  });

  Future<void> discover() => _run(() async {
    services = await ble.discoverServices();
    _log('${services.length} servis bulundu.');
  });

  /// Cancellation remains available while connect or another operation waits.
  Future<void> disconnect() async {
    try {
      await ble.disconnect();
      _clearConnection();
    } catch (e) {
      error = e.toString();
      _log('Bağlantı kesilemedi: $e');
    }
    _changed();
  }

  Future<void> read(String service, String characteristic) => _run(() async {
    final value = await ble.read(serviceUuid: service, characteristicUuid: characteristic);
    values[targetKey(service, characteristic)] = value;
    _log('Okundu $characteristic: ${hex(value)}');
  });

  Future<void> write(String service, String characteristic, String input, bool withResponse) =>
      _run(() async {
        final text = input.replaceAll(RegExp(r'\s'), '');
        if (text.isEmpty || text.length.isOdd ||
            !RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
          throw const FormatException('Hex veri girin. Örnek: 01 A0 FF');
        }
        final value = Uint8List.fromList([
          for (var i = 0; i < text.length; i += 2) int.parse(text.substring(i, i + 2), radix: 16),
        ]);
        await ble.write(serviceUuid: service, characteristicUuid: characteristic,
            value: value, withResponse: withResponse);
        _log('Gönderildi $characteristic: ${hex(value)}');
      });

  Future<void> toggleNotify(String service, String characteristic) => _run(() async {
    final key = targetKey(service, characteristic);
    final enabled = !notifying.contains(key);
    await ble.setNotify(serviceUuid: service, characteristicUuid: characteristic, enabled: enabled);
    if (enabled) {
      notifying.add(key);
    } else {
      notifying.remove(key);
    }
    _log('Bildirim ${enabled ? 'açıldı' : 'kapatıldı'}: $characteristic');
  });

  void _onEvent(BleEvent event) {
    switch (event) {
      case BleAdapterEvent(:final state):
        adapter = state;
        scanning = state.scanning;
        connectedId = state.connectedDeviceId;
      case BleScanResultEvent(:final device):
        _devices[device.id] = device;
      case BleScanStateEvent(:final scanning):
        this.scanning = scanning;
      case BleConnectionEvent(:final deviceId, :final state, :final status):
        _log('$deviceId: ${state.name} (GATT $status)');
        if (state == BleConnectionState.connected) connectedId = deviceId;
        if (state == BleConnectionState.disconnected) _clearConnection();
      case BleNotificationEvent(:final serviceUuid, :final characteristicUuid, :final value):
        values[targetKey(serviceUuid, characteristicUuid)] = value;
        _log('Bildirim $characteristicUuid: ${hex(value)}');
      case BleErrorEvent(:final code, :final message):
        error = '$code: $message';
        _log(error!);
    }
    _changed();
  }

  void _clearConnection() {
    connectedId = null;
    services = [];
    notifying.clear();
    values.clear();
  }

  void _log(String message) {
    logs.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)} $message');
    if (logs.length > 80) logs.removeLast();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_releaseRadio());
    } else if (state == AppLifecycleState.resumed && !busy) {
      unawaited(refresh());
    }
  }

  Future<void> _releaseRadio() async {
    if (!nativeAvailable) return;
    try {
      await ble.stopScan();
      await ble.disconnect();
    } catch (e) {
      _log('Oturum kapatma hatası: $e');
      error = e.toString();
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_releaseRadio());
    super.dispose();
  }

  static String hex(List<int> bytes) => bytes
      .map((v) => v.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}
