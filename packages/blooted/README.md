# blooted

**Kontrol uygulamada, Bluetooth işlemleri pakette.**

Android için Flutter BLE eklentisi. Hazır Bluetooth eklentisi kullanmaz;
Kotlin'deki `BluetoothLeScanner` ve `BluetoothGatt` API'lerine Platform Channel
ile erişir.

> Bu sürüm Android BLE merkez cihaz (central / GATT client) içindir.
> Klasik Bluetooth / SPP, yazıcı protokolleri, ses, iOS ve web desteklenmez.
> BLE destekli gerçek Android telefon ve yayın yapan bir BLE çevre cihazı gerekir.

## Sorumluluklar

| Paket | Paketi kullanan uygulama |
| --- | --- |
| Yerel Android BLE API çağrıları | İzin penceresinin ne zaman açılacağı |
| MethodChannel ile komut ve sonuçlar | Hangi cihazın seçileceği |
| EventChannel ile cihaz ve bağlantı olayları | Ne zaman bağlanıp bağlantının kesileceği |
| İzin isteği için açık API | Servis / karakteristik UUID seçimi |
| Tarama ve GATT zaman aşımı, bağlantı temizliği | Veri protokolü, parçalama, yeniden deneme |
| Bildirim için CCCD yazımı | UI, uygulama yaşam döngüsü, abonelikler |

Paket kendi başına tarama başlatmaz, izin penceresi açmaz, Bluetooth'u açmaz,
otomatik bağlanmaz veya tekrar bağlanmaz. Bağlantıdan sonra servis keşfi de
uygulamanın açıkça çağırdığı bir işlemdir.

## Gereksinimler

- Flutter 3.32+, Dart 3.8+
- Android minSdk 21, compileSdk 35 veya üstü
- Kotlin 2.1 / Android Gradle Plugin 8.7.3 ile oluşturulmuş Android eklentisi
- APK derlemek / telefonda çalıştırmak için yerel Android SDK ve uyumlu JDK
- Gerçek BLE donanımı

## Projeye ekleme

Henüz pub.dev'de yayımlanmadı. Paket klasörünü projenizin yanına kopyalayıp
uygulamanızın `pubspec.yaml` dosyasına ekleyin:

```yaml
dependencies:
  flutter:
    sdk: flutter
  blooted:
    path: ../blooted
```

Bu depodaki örnek proje `example/pubspec.yaml` içinde `path: ../` ile doğrudan
bu paketi kullanır.

```sh
cd packages/blooted/example
flutter pub get
flutter run -d <android-cihaz-id>
```

`flutter devices` ile cihaz kimliğini görebilirsiniz. Bu paket web eklentisi
değildir; tarayıcı önizlemesi Bluetooth işlemlerini çalıştırmaz.

## Kullanım

```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:blooted/blooted.dart';

final ble = Blooted();

// İşlemlerden önce dinlemeye başlayın.
final subscription = ble.events.listen((event) {
  switch (event) {
    case BleScanResultEvent(:final device):
      print('${device.name} / ${device.id} / ${device.rssi} dBm');
      // Listeyi device.id ile tekilleştirmek uygulamanın sorumluluğudur.
    case BleNotificationEvent(:final value):
      print('Gelen baytlar: $value');
    case BleConnectionEvent(:final state, :final status):
      print('Bağlantı: $state, GATT durumu: $status');
    case BleErrorEvent(:final code, :final message):
      print('$code: $message');
    default:
      break;
  }
}, onError: (Object error) {
  print('Olay kanalı hatası: $error');
});

// Örneğin bir "İzin ver" düğmesinden:
final permissions = await ble.requestPermissions();
if (!permissions.granted) {
  throw StateError('İzinler reddedildi: ${permissions.deniedPermissions}');
}

final state = await ble.getState();
if (!state.supported || !state.enabled || !state.locationEnabled) {
  throw StateError('Android Bluetooth / konum ayarlarını kontrol edin.');
}

// Tarama zaman aşımında otomatik durur. Filtre isteğe bağlıdır.
await ble.startScan(
  timeout: const Duration(seconds: 10),
  serviceUuids: ['180F'], // Battery Service örneği; tüm cihazlar için [].
);

// Kullanıcının listeden seçtiği gerçek cihaz adresi:
await ble.stopScan();
await ble.connect(selectedDeviceId);
final services = await ble.discoverServices();
// services içinden cihazınıza ait UUID ve desteklenen özellikleri seçin.

final battery = await ble.read(
  serviceUuid: '180F',
  characteristicUuid: '2A19',
);

// Yalnızca yazılabilir bir karakteristik için:
await ble.write(
  serviceUuid: writableServiceUuid,
  characteristicUuid: writableCharacteristicUuid,
  value: Uint8List.fromList([0x01, 0xA0]),
  withResponse: true,
);

// Yalnızca notify / indicate destekleyen bir karakteristik için:
await ble.setNotify(
  serviceUuid: notifyServiceUuid,
  characteristicUuid: notifyCharacteristicUuid,
  enabled: true,
);

// Ekran / oturum kapanırken uygulama temizler:
await ble.disconnect();
await subscription.cancel();
```

Yukarıdaki `selectedDeviceId`, `writable*` ve `notify*` değişkenleri uygulamanın
seçtiği cihaz / karakteristik bilgileridir; örnek UUID'ler her cihazda bulunmaz.
Çalıştırılabilir tam örnek `example/lib/` altındadır. Her çağrıyı uygulamanızda
`try/catch` ile ele alın; native hatalar `PlatformException` ile döner.

## API

| İşlem | Sonuç |
| --- | --- |
| `getState()` | Destek, açık/kapalı, izin, konum, tarama ve bağlı cihaz durumu |
| `requestPermissions()` | `granted` ve `deniedPermissions` |
| `startScan(serviceUuids:, timeout:)` | BLE reklam taraması; cihazlar olay akışında |
| `stopScan()` | Etkin taramayı durdurur; tekrar çağırmak güvenlidir |
| `connect(deviceId, timeout:)` | Bağlanınca tamamlanır; varsayılan 15 sn zaman aşımı |
| `disconnect()` | Bekleyen bağlantı / GATT işlemini iptal eder ve oturumu kapatır |
| `discoverServices()` | Servisler, karakteristikler ve desteklenen işlemler |
| `read(serviceUuid:, characteristicUuid:)` | `Uint8List` |
| `write(serviceUuid:, characteristicUuid:, value:, withResponse:)` | 1–20 bayt |
| `setNotify(serviceUuid:, characteristicUuid:, enabled:)` | CCCD yazımı tamamlanınca döner |

### Olay akışı

`BleAdapterEvent`, `BleScanResultEvent`, `BleScanStateEvent`,
`BleConnectionEvent`, `BleNotificationEvent`, `BleErrorEvent`.

Olaylar anlıktır; tekrar oynatılmaz. Dinlemeye başlanınca adaptör durum özeti
gelir. Android'deki olay aboneliği paylaşılır; `Blooted()` nesneleri bağımsız
Bluetooth bağlantıları oluşturmaz. Abonelik iptali bağlantıyı otomatik kesmez.
`getState()` ile mevcut durumu yeniden okuyabilirsiniz.

### Sınırlar

- Bir Flutter engine için bir etkin tarama ve bir GATT bağlantısı.
- GATT işlemlerini sırayla `await` edin; eşzamanlı çağrı `busy` hatası verir.
- GATT işlemi 10 saniyede bitmezse bağlantı kapatılır. Bu, gecikmiş bir Android
  callback'inin sonraki işlemi yanlış tamamlamasını önler.
- Tarama / bağlantı zaman aşımı 1–120 saniye arasında ayarlanabilir.
- Yazma 1–20 baytla sınırlıdır; MTU pazarlığı veya gizli veri parçalama yapılmaz.
- `withResponse: false` yalnızca ilgili özelliği destekleyen karakteristiklerde
  kullanılabilir. Başarılı sonuç, çevre cihazının uygulama komutunu işlediğine
  dair protokol düzeyinde bir onay değildir.
- UUID'ler 16 / 32 / 128 bit biçimlerinde kabul edilip tam UUID'ye dönüştürülür.
- UUID başına yinelenen GATT servis / karakteristik örnekleri ayırt edilmez.
- Eşleşme / bonding yönetimi ve şifreli karakteristikler için özel akış yoktur;
  Android'in varsayılan güvenlik davranışı ve GATT hata kodları kullanılır.
- Arka plan servisi, yeniden bağlanma ve cihaz başına veri protokolü yoktur.
- Örnek uygulama arka plana geçtiğinde bağlantıyı keser ve taramayı durdurur.
  Bu, **uygulama politikasıdır**; paket böyle bir yaşam döngüsü kararı vermez.

## Android izinleri

Manifest bildirimleri eklentiyle birleştirilir:

- Android 12+: `BLUETOOTH_SCAN` ve `BLUETOOTH_CONNECT`.
- Android 6–11: `ACCESS_FINE_LOCATION`, ayrıca konum servisleri açık olmalı.
- Android 5: eski `BLUETOOTH` ve `BLUETOOTH_ADMIN` izinleri.

`requestPermissions()` yalnızca uygulama çağırırsa sistem penceresini açar ve
ön planda bir Activity gerektirir. Kalıcı red durumunda Android yeniden pencere
göstermeyebilir; uygulama kullanıcıya Android ayarlarından izin vermesini
söylemelidir. Bluetooth kapalıysa kullanıcı Android ayarlarından açar.

`neverForLocation` kullanılır. Konum amaçlı tarama yapılmaz; Android bazı
konum beacon reklamlarını filtreleyebilir. Konum beacon uygulaması bu sürümün
kapsamında değildir.

## Kanal sözleşmesi

- MethodChannel: `dev.blooted/methods`
- EventChannel: `dev.blooted/events`
- Tüm native sonuçlar ve olaylar ana iş parçacığında iletilir.
- Android API 33+ için yeni, önceki sürümler için eski GATT callback'leri kullanılır.
- Bilinen hatalar: `permission_denied`, `bluetooth_off`, `location_off`,
  `unsupported`, `busy`, `not_connected`, `not_found`, `not_supported`,
  `invalid_argument`, `timeout`, `disconnected`, `cancelled`, `gatt_error`,
  `scan_failed`, `scanner_unavailable`, `operation_failed`, `connect_failed`,
  `no_activity`, `activity_detached`, `native_error`.

## Windows / Gradle sürüm hatası

`Your project's Gradle version (...) is lower than Flutter's minimum supported
version of 8.14.0` hatasında `example/android/gradle/wrapper/gradle-wrapper.properties`
dosyasındaki dağıtımın `gradle-8.14.3-bin.zip` olduğundan emin olun.
Bu sürüm Gradle 8.14.3 kullanır ve resmi SHA-256 doğrulamasını içerir.

Önceki ZIP'i indirdiyseniz güncel ZIP'i ayrı bir klasöre açın veya ilgili
wrapper dosyasını güncelleyin. Örnek uygulama klasöründen çalıştırın:

```powershell
flutter clean
flutter pub get
flutter run
```

İlk çalıştırmada Gradle 8.14.3 indirilir. İnternet bağlantısı gerekir.
`--android-skip-build-dependency-validation` ile denetimi atlamak yerine
sürüm uyumsuzluğunu düzeltin.

`Starting AGP 9+` önerisi tek başına projenin AGP 9 kullandığını göstermez.
Bu proje AGP 8.7.3 kullanır; bu Gradle hatası için AGP 9'a geçmeyin veya
`android.newDsl` ayarını rastgele değiştirmeyin.

## Kontroller

```sh
cd packages/blooted
flutter analyze
flutter test
cd example
flutter run -d <android-cihaz-id>
```

Dart testleri kanal parametrelerini ve model dönüşümlerini doğrular; fiziksel
BLE testi yerine geçmez. Android SDK / telefon olmadan native APK derleme ve
gerçek tarama / GATT alışverişi doğrulanamaz. Donanımda en az şu durumları
kontrol edin: izin red / kabul, Bluetooth kapalı, cihaz tarama, bağlanma, servis
keşfi, okuma, yazma, bildirim, çevre cihazı kapanması, zaman aşımı ve yeniden
bağlanma.
