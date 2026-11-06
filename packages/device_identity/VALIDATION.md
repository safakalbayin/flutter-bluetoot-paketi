# IMEI izin ve yaşam döngüsü doğrulaması

## Ortam ve sonuç — 6 Kasım 2026

- Flutter 3.32.0 / Dart 3.8.0; JDK 21; Gradle 8.14.3.
- Gerçek Kotlin eklentisi, Flutter embedding ve Android API sınıflarına karşı
  SDK bağımsız JVM test projesinde başarıyla derlendi.
- Robolectric 4.14.1 + JUnit 4: **94 test geçti**, hata/atlanan test yok.
- Mevcut paket Dart testleri: **8 test geçti**.
- Örnek uygulama ekran testleri: **14 test geçti**.
- `flutter analyze`: paket ve örnek uygulama kaynaklarında sorun yok.
- Android SDK, Android emülatörü ve bağlı fiziksel Android cihaz bulunmadı.
  Bu nedenle APK/AAR derlemesi, manifest birleştirmesi ve cihaz doğrulaması
  **yapılmadı**. Linux masaüstü cihazı Android doğrulaması olarak sayılmadı.

## Native kapsam

Testler `android/src/test/kotlin/dev/deviceidentity/device_identity/DeviceIdentityPluginTest.kt`
altında; gerçek üretim kodu değiştirilmeden çalışır.

| Senaryo | API ortamları | Kontrol |
| --- | --- | --- |
| Android 6–9 izin reddi | 23–28 | Yalnızca READ_PHONE_STATE isteği; red sonrası `denied`, IMEI için `permissionRequired`, modem çağrısı yok |
| İzin kabulü / önceden verilmiş izin | 23–28 | Tek sonuç, gereksiz ikinci pencere yok |
| İzin isteği sürerken Activity döndürme | 23–28 | Eski listener kaldırılır, yenisi eklenir; Future korunur, ikinci istek `busy`; callback bir kez tamamlar |
| Kalıcı Activity/engine ayrılması | 23–28 | Bekleyen istek `activity_detached`; geç callback ikinci sonuç üretmez; Activity yoksa `no_activity` |
| İptal / ilgisiz callback / yeniden deneme | 23–28 | İlgisiz request code tüketilmez; boş callback red ile sonuçlanır; yeniden istek mümkündür |
| İzin penceresi açılamaması | 23, 28 | Güvenli `permission_request_failed`, takılı kalan `busy` yok |
| Android 10+ kısıtlaması | 29, 30, 35 | İzin penceresi açılmaz, `restricted`; simüle SecurityException rapora güvenli aktarılır |
| Telefon modemi yok | 23–30 seçili tüm API'ler, 35 | `notRequired` / `noTelephony`; izin ve modem çağrısı yok |
| Çoklu modem, kısmi erişim | 26–30 seçili tüm API'ler, 35 | Her slot ayrı; başarılı/kısıtlı/boş slotlar ve indeksler korunur |
| Eski GSM / CDMA | 23–25 | GSM yalnızca açık okumada; CDMA MEID değeri IMEI olarak sunulmaz |
| Boş, hatalı veya sıfır kimlik | 23–30 seçili tüm API'ler, 35 | `unavailable`; geçersiz değer gösterilmez |
| Eksik servis / desteklenmeyen API | 23–30 seçili tüm API'ler, 35 | `unavailable` |
| Servis / modem sayısı güvenlik hataları | İlgili eski/yeni API'ler | Beklenen durum döner; exception içeriği dışarı verilmez |

API 23/24/25/26/27/28 sırasıyla Android 6/7.0/7.1/8.0/8.1/9;
29/30/35 ise Android 10/11/15'tir. Bu, bütün ara/yeni Android sürümlerinin
veya üretici yazılımlarının test edildiği anlamına gelmez.

## Ekran kapsamı

`example/test/device_page_test.dart`, gerçek `DevicePage` widget'ını kanal
yanıtlarını taklit ederek sınar:

- Açılış ve yenilemede yalnızca cihaz bilgileri; otomatik IMEI okuması yok.
- API 23–28 için red sonrası okuma yapılmaması; kullanıcının yeniden
  başlatıp izin verdiği akışta tek IMEI çağrısı.
- Bekleyen izin sırasında düğmelerin kapalı olması; ekran boyutu/yön
  değişiminde yinelenen izin isteği veya kaybolan sonuç olmaması.
- API 29/30/35 ve modemsiz cihazlarda izin düğmesinin gösterilmemesi.
- Kısıtlı erişimin ve çoklu modemlerin ayrı sonuçlarının gösterilmesi.
- Ekran kapatıldıktan sonra tamamlanan izin isteğinin IMEI okumaması.

Widget yön değişimi testi OS Activity yeniden oluşturma testi değildir;
native testte Flutter ActivityAware callback'leri ayrıca sınanır.

## Gizlilik

Hiçbir gerçek IMEI okunmadı, raporlanmadı veya loglanmadı. Tüm kimlik
verileri test içinde uydurulmuştur. Log/exception mesajlarının kimlik
sızdırmadığı işaretleyici bir metinle kontrol edilir. Root, ayrıcalıklı izin,
reflection, alternatif kimlikle IMEI taklidi veya başka erişim aşımı yoktur.
Üretim izinleri ve okuma davranışı değiştirilmemiştir.

## Fiziksel cihaz için kalan kontrol listesi

Android SDK ve yetkili test cihazları sağlandığında:

1. `example` içinde `flutter build apk --debug` ile APK üretin; birleşmiş
   manifestte READ_PHONE_STATE için `maxSdkVersion=28` ve isteğe bağlı
   telephony özelliğini doğrulayın.
2. Android 6–9'da oku → izin gerekli; izin iste → reddet; tekrar izin iste
   → kabul et akışlarını ve ayarlardan izin kaldırmayı kontrol edin.
3. İzin penceresi açıkken döndürün; sonuç bir kez dönmeli, düğmeler tekrar
   kullanılabilmeli. Kalıcı red/ayarlar ve Activity kapatma durumlarını deneyin.
4. Sıradan Android 10+ kurulumunda izin penceresi açılmamalı; erişim
   kısıtlaması açıkça gösterilmeli, bir alternatif kimlik sunulmamalı.
5. Telefon modemsiz cihazda `noTelephony`; çoklu modemli cihazda slotlar,
   boş ve kısmen erişilebilir sonuçlar ayrı gösterilmeli. API 23–25'te paket
   yalnızca eski varsayılan GSM modem API'sini kullanır.
6. Yalnızca API seviyesi, cihaz kategorisi, beklenen/gerçekleşen durum ve
   geçti/kaldı kaydedin. IMEI'yi kopyalamayın; IMEI görünen ekran görüntüsü,
   video veya logcat çıktısını rapora eklemeyin.

Tekrar çalıştırma komutları için [native test rehberine](android/native-tests/README.md)
ve paket README'sindeki doğrulama bölümüne bakın.
