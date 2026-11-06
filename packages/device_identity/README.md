# device_identity

Android cihaz bilgisi ve **Android izin verdiğinde** IMEI okuma için Flutter
paketi. Kotlin Android API'lerine `MethodChannel` ile erişir.

Blooted Bluetooth paketinden bağımsızdır; mevcut Flutter projenize ekleyebilirsiniz.
Paketi uygulama yönetir. Örnek Flutter uygulaması `example/` klasöründedir.

## IMEI hakkında önemli sınır

**Android 10+ üzerinde normal uygulamalar IMEI okuyamaz.** Kullanıcıdan sıradan
telefon izni almak bu kısıtlamayı kaldırmaz.

Android'in sistem / operatör ayrıcalıkları gibi özel koşulları vardır, ancak
bu paket bu ayrıcalıkları sağlamaz veya kısıtlamayı aşmaz. Standart uygulamada
`restricted` sonucu beklenmelidir. İnternet izni, root, reflection, gizli API,
seri numarası veya Android ID ile IMEI taklidi kullanılmaz.

Android'in resmi açıklaması:
https://developer.android.com/about/versions/10/privacy/changes#non-resettable-device-ids

| Ortam | Davranış |
| --- | --- |
| Android 5 (API 21–22) | Manifestteki telefon izniyle, cihaz destekliyorsa IMEI |
| Android 6–9 (API 23–28) | Uygulama açıkça telefon izni ister; izin verilirse okuma denenir |
| Android 10+ (API 29+) | Normal uygulama erişimi kısıtlı; yararsız izin penceresi açılmaz |
| Telefon modemi olmayan tablet | `noTelephony` |
| IMEI sağlamayan modem / emülatör | `unavailable` veya OS'nin erişim kısıtı |
| iOS / web / masaüstü | `UnsupportedError` |

Android 8+ üzerinde erişilebilen modem slotları ayrı listelenir. Android 5–7'de
yalnızca varsayılan GSM modeminin kimliği okunur; CDMA MEID, IMEI olarak gösterilmez.
Modem slotunun olması SIM kart takılı olduğu anlamına gelmez.

## Gösterilen cihaz bilgileri

- Üretici, marka, model, cihaz / ürün kodu ve donanım
- Android sürümü, API seviyesi ve mevcutsa güvenlik yaması
- CPU mimarileri
- Sistemin gördüğü toplam RAM
- Dahili veri bölümünün toplam ve kullanılabilir kapasitesi
- Telefon modemi bulunup bulunmadığı
- Açık kullanıcı isteğiyle okunabilirse IMEI; değilse erişim durumu ve açıklama

RAM ve depolama, Android'in raporladığı bayt değerleridir; ürün kutusundaki
kapasiteden farklı olabilir. Örnek ekran bu değerleri **GiB** birimiyle gösterir.

## Gereksinimler

- Flutter >=3.32, Dart >=3.8
- Android minSdk 21, compileSdk 35 veya üstü
- Android SDK / JDK kurulumu ve gerçek Android cihaz
- Örnek uygulama: Gradle 8.14.3, AGP 8.7.3, Kotlin 2.1.0

## Projeye ekleme

Paket henüz pub.dev'de yayımlanmadı. `device_identity` klasörünü projenizin yanına
koyup uygulamanızın `pubspec.yaml` dosyasına ekleyin:

```yaml
dependencies:
  flutter:
    sdk: flutter
  device_identity:
    path: ../device_identity
```

Sonra **uygulamanızın pubspec.yaml dosyasının bulunduğu klasörde**:

```powershell
flutter pub get
```

## Örnek uygulamayı çalıştırma

ZIP'i çıkardıktan sonra terminali dış ZIP klasöründe değil,
**device_identity/example** klasöründe açın:

```powershell
cd device_identity
flutter pub get
cd example
flutter pub get
flutter devices
flutter run
```

Gerçek Android telefonunuzu seçin. Chrome / Windows üzerinden cihaz IMEI'si
okunamaz. Terminal `Expected to find project root` derse yanlış klasördesiniz;
`pubspec.yaml` dosyasının bulunduğu klasöre geçin.

Ekran cihaz bilgilerini açılışta okur. IMEI için **IMEI bilgisini oku** düğmesine
basın. Android 6–9'da gerekiyorsa **Telefon izni ver ve oku** düğmesini kullanın.
İzin kalıcı reddedildiyse Android uygulama ayarlarından elle izin verin.

## API

```dart
import 'package:device_identity/device_identity.dart';

final device = DeviceIdentity();

// Telefon izni gerekmez.
final info = await device.getDeviceInfo();
// info.manufacturer, info.model, info.androidVersion, info.totalRamBytes, ...

// IMEI isteği bir kullanıcı işlemine bağlanmalıdır.
var report = await device.getImei();
if (report.status == ImeiStatus.permissionRequired) {
  final permission = await device.requestPhonePermission();
  if (permission.status == PhonePermissionStatus.granted) {
    report = await device.getImei();
  }
}

// UI'da report.message ve report.entries gösterin.
// entry.imei null ise kullanıcıya entry.message ile nedenini açıklayın.
// Bu bilgileri loglara yazmayın.
```

Üç çağrı da `Future` döndürür. Native / kanal hatalarını uygulamada `try/catch`
ile ele alın. Beklenen IMEI kısıtları exception yerine tipli durum olarak döner:

- `available`: en az bir modem için IMEI okundu
- `permissionRequired`: Android 9 veya öncesinde telefon izni gerekli
- `restricted`: Android erişimi engelliyor
- `unavailable`: sistem kullanılabilir bir IMEI sağlamadı
- `noTelephony`: telefon modemi yok

`requestPhonePermission()` yalnızca uygulama çağırdığında ve Android 6–9'da
izin penceresi açar. Ön planda Activity gerektirir. Android 10+ için sıradan
telefon izni IMEI erişimi sağlamadığı için bu paketin manifestindeki izin
`maxSdkVersion=28` ile sınırlıdır. Özel kurumsal / sistem uygulaması yetkilendirme
akışı bu sürümün kapsamı dışındadır.

Kanal adı: `dev.deviceidentity/methods`. Beklenmeyen native hata
`device_info_error`; izin isteği hataları `busy`, `no_activity`,
`activity_detached`, `permission_request_failed` kodlarıyla döner.

## Gizlilik

Paket bilgileri kaydetmez, loglamaz ve ağ üzerinden göndermez. Örnek uygulama
IMEI'yi yalnızca düğmeye basılınca okur ve ekranda tutar. Üretimde kalıcı cihaz
kimliğine gerçekten ihtiyacınız olup olmadığını değerlendirin; IMEI'yi
analitik / çökme günlüklerine eklemeyin.

## Doğrulama

```powershell
cd device_identity
flutter analyze
flutter test
```

Dart testleri veri modellerini ve kanal sözleşmesini kontrol eder.
Örnek ekranın testleri için `cd example` ardından `flutter test` çalıştırın.
Android 6–9 izin/Activity akışları, Android 10+ kısıtlamaları ve modem
senaryoları için SDK bağımsız native testler de vardır:
[native test rehberi](android/native-tests/README.md).

Kotlin JVM derlemesi ve simüle native testler başarılıdır; Android SDK ve
fiziksel cihaz olmadan APK derleme ve gerçek IMEI erişimi doğrulanmış sayılmaz.
Kapsam, sonuçlar ve kimlik içermeyen cihaz kontrol listesi:
[doğrulama raporu](VALIDATION.md).
