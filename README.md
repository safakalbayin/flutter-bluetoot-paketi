# Blooted — Flutter Bluetooth paketi

Android BLE için Platform Channel tabanlı Flutter eklentisi ve onu kullanan
örnek uygulama.

- **Paket:** [`packages/blooted`](packages/blooted)
- **Doküman / API / kurulum:** [`packages/blooted/README.md`](packages/blooted/README.md)
- **Flutter örnek uygulaması:** [`packages/blooted/example`](packages/blooted/example)

Paket native işlemleri sunar; bağlantı ve veri protokolü kararlarını uygulama
verir. Bu bir web uygulaması veya tarayıcı Bluetooth demosu değildir.

```sh
cd packages/blooted
flutter pub get
flutter analyze
flutter test
cd example
flutter run -d <android-cihaz-id>
```

Android SDK ve fiziksel BLE cihazı gerekir. Bu sürüm iOS ve klasik Bluetooth
(SPP) içermez.

## Cihaz bilgisi ve IMEI paketi

- Paket: [`packages/device_identity`](packages/device_identity)
- Android örneği: [`packages/device_identity/example`](packages/device_identity/example)
- Etiketli web simülasyonu: [`artifacts/device-identity-preview`](artifacts/device-identity-preview)

Cihaz bilgisi önizlemesinin senaryo seçimi ve ekranları Flutter/Dart ile
yazılmıştır. Yerelde çalıştırmak için:

```sh
cd packages/device_identity/example
flutter pub get
flutter run -d chrome -t lib/main_preview.dart
```

Tarayıcı ekranı örnek verilerle çalışan simülasyondur; gerçek cihaz taraması veya
IMEI okuması yapmaz. Gerçek Android uygulaması `flutter run -d <android-cihaz-id>`
ile normal `main.dart` girişinden çalışır. Android donanım katmanı Platform
Channel üzerinden Kotlin kullanır. Android 10+ IMEI kısıtları aşılmaz.

Bu depodaki eski Blooted web önizlemesi ve Replit şablon araçları ayrı
ürünlerdir; cihaz bilgisi ekranının Dart'a taşınması onları değiştirmez.
