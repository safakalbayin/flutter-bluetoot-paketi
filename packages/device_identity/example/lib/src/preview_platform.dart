import 'package:device_identity/device_identity_platform_interface.dart';

/// Sample data for the explicitly labelled browser simulation only.
/// Never imported by the actual Android entry point or the plugin package.
enum PreviewScenario {
  grant('android9-grant'),
  deny('android9-deny'),
  restricted('android10-restricted'),
  noModem('no-modem');

  const PreviewScenario(this.key);
  final String key;

  static PreviewScenario fromKey(String? key) =>
      values.where((scenario) => scenario.key == key).firstOrNull ?? restricted;
}

class PreviewDevicePlatform extends DeviceIdentityPlatform {
  PreviewDevicePlatform(this.scenario);

  final PreviewScenario scenario;
  bool _granted = false;
  bool get _legacy => scenario == PreviewScenario.grant ||
      scenario == PreviewScenario.deny;
  bool get _hasModem => scenario != PreviewScenario.noModem;

  @override
  Future<Object?> invoke(String method) async {
    // Simulates asynchronous UI loading, not a native channel round trip.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    switch (method) {
      case 'getDeviceInfo':
        return {
          'manufacturer': 'Örnek üretici · SİMÜLASYON',
          'brand': 'Demo marka',
          'model': _hasModem ? 'Örnek telefon' : 'Örnek modemsiz tablet',
          'device': 'demo_device',
          'product': 'demo_product',
          'hardware': 'Örnek donanım',
          'androidVersion': _legacy ? '9 (simüle)' : '10+ (simüle)',
          'sdkInt': _legacy ? 28 : 29,
          'securityPatch': null,
          'supportedAbis': ['arm64-v8a (örnek)'],
          'totalRamBytes': 4 * 1024 * 1024 * 1024,
          'totalStorageBytes': 64 * 1024 * 1024 * 1024,
          'availableStorageBytes': 32 * 1024 * 1024 * 1024,
          'hasTelephony': _hasModem,
        };
      case 'requestPhonePermission':
        if (!_hasModem) {
          return {'status': 'notRequired', 'message': 'Simülasyon: telefon modemi yok.'};
        }
        if (!_legacy) {
          return {'status': 'restricted', 'message': 'Simülasyon: Android 10+ IMEI erişimini kısıtlıyor.'};
        }
        _granted = scenario == PreviewScenario.grant;
        return {
          'status': _granted ? 'granted' : 'denied',
          'message': _granted
              ? 'Simülasyon: telefon izni kabul edildi. Gerçek sistem penceresi açılmadı.'
              : 'Simülasyon: telefon izni reddedildi. Gerçek sistem penceresi açılmadı.',
        };
      case 'getImei':
        if (!_hasModem) {
          return _report('noTelephony', 'Simülasyon: bu örnek cihazda telefon modemi yok.');
        }
        if (!_legacy) {
          return _report('restricted', 'Simülasyon: Android 10+ normal uygulamalara IMEI erişimi vermez.');
        }
        if (!_granted) {
          return _report('permissionRequired',
              'Simülasyon: önce “Telefon izni ver ve oku” düğmesine basın.');
        }
        return _report(
          'available',
          'Simülasyon sonucu. Aşağıdaki DEMO metinleri gerçek IMEI numarası değildir.',
          [
            for (var slot = 0; slot < 2; slot++)
              {
                'slotIndex': slot,
                'status': 'available',
                'message': 'Yalnızca arayüz denemesi.',
                'imei': 'DEMO-IMEI-${slot + 1} · gerçek numara değil',
              },
          ],
        );
      default:
        throw UnsupportedError('Simulation does not implement $method');
    }
  }

  Map<String, Object?> _report(
    String status,
    String message, [
    List<Map<String, Object?>> entries = const [],
  ]) => {'status': status, 'message': message, 'entries': entries};
}
