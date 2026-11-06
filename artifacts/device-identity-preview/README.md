# Cihaz Bilgisi — Flutter/Dart önizlemesi

Senaryo seçimi, açıklamalar, sıfırlama ve cihaz ekranı dahil kullanıcı arayüzü
Flutter/Dart ile yazılmıştır. React, TypeScript veya iframe kullanılmaz.
Flutter web derlemesinin ürettiği JavaScript dosyaları tarayıcıda çalışır;
bunlar elle yazılmış uygulama kaynakları değildir.

- Arayüz: `packages/device_identity/example/lib/main_preview.dart`
- Senaryo sayfası: `packages/device_identity/example/lib/src/preview_shell.dart`
- Derleme: `dart run tool/build.dart`
- Sunucu: `PORT=18427 BASE_PATH=/device-identity/ dart run tool/serve.dart`

Replit workflow'u derlemeyi ve Dart HTTP sunucusunu otomatik başlatır.
Node/pnpm sadece mevcut çalışma alanının komut girişidir; ekranı çalıştırmaz.
Üretim çıktısı `dist/public/` altına üretilen statik dosyalardır.

Yerelde yalnızca Flutter SDK ile:

```sh
cd packages/device_identity/example
flutter pub get
flutter run -d chrome -t lib/main_preview.dart
```

Bu, örnek verilerle çalışan **etiketli simülasyondur**, Android emülatörü
değildir. Gerçek telefon bilgisi ve IMEI okunmaz. Native Android örneği
`lib/main.dart` ile çalışır; donanım erişimi için gereken Kotlin katmanı korunur.
