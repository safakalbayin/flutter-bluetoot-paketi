# Cihaz Bilgisi örnek uygulaması

Bu klasör **çalıştırılabilir Flutter uygulamasıdır**; `pubspec.yaml` burada bulunur.
Üstteki `device_identity` paketini `path: ../` ile kullanır.

```powershell
flutter pub get
flutter devices
flutter run
```

Android telefonunu seç. Marka/model ve donanım bilgileri açılışta görünür.
IMEI'yi **IMEI bilgisini oku** düğmesiyle iste. Android 10+ üzerinde normal
uygulama için erişim kısıtı gösterilmesi beklenen davranıştır.

Tam kurulum ve API: [Paket dokümanı](../README.md).

## Etiketli tarayıcı simülasyonu

Kullanıcının onayıyla ayrı bir `lib/main_preview.dart` girişi eklenmiştir.
Normal `flutter run` ve Android APK'sı hâlâ `lib/main.dart` kullanır; native
pakete sahte veri veya web desteği eklenmez.

Senaryo seçimi, sıfırlama ve sonuç ekranı dahil web arayüzü Flutter/Dart'tır;
React/TypeScript sarmalayıcı veya iframe yoktur. Tarayıcı simülasyonu gerçek
`DevicePage` ekranını ayrı bir örnek transport ile çalıştırır.
Gerçek Android emülatörü değildir ve OS izin / modem davranışını
doğrulamaz. Bütün veriler örnektir; IMEI yerine açıkça `DEMO-IMEI` metni gösterilir.

Replit'te **Cihaz Bilgisi — Etiketli Simülasyon** önizlemesinde dört senaryo:

- Android 9 izin kabulü: önce **IMEI bilgisini oku**, sonra **Telefon izni ver ve oku**.
- Android 9 izin reddi: izin düğmesi red sonucu üretir, IMEI görünmez.
- Android 10+ IMEI kısıtı: IMEI isteği `restricted` döner, izin düğmesi yoktur.
- Modemsiz cihaz: IMEI isteği `noTelephony` döner.

Senaryo değiştirme ve sıfırlama örnek oturum durumunu temizler. Gerçek sistem
izin penceresi açılmaz. Yerelde tarayıcı denemesi için:

```sh
flutter run -d chrome -t lib/main_preview.dart
```
