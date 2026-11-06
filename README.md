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
