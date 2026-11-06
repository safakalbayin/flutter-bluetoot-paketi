# SDK olmadan native testler

Bu JVM projesi gerçek `../src/main/kotlin` eklenti kodunu Flutter Android
embedding ile derler. `../src/test/kotlin` altındaki aynı testler hem burada
hem SDK bulunan Flutter/Android Gradle projesinde çalıştırılabilir.

## Gereksinimler ve çalıştırma

- JDK 21, Gradle 8.14.3
- Flutter SDK ve Android embedding önbelleği (`flutter precache --android`)
- İlk çalıştırmada Maven Central, Google Maven ve Gradle depolarına erişim

Depo kökünden (SDK yolunu kendi kurulumunuzla değiştirin):

```sh
gradle -p packages/device_identity/android/native-tests \
  -PflutterSdk=/path/to/flutter test --no-daemon
```

PowerShell:

```powershell
gradle -p packages/device_identity/android/native-tests "-PflutterSdk=C:\src\flutter" test --no-daemon
```

`-PflutterSdk` yerine `FLUTTER_ROOT` kullanılabilir. Gradle kurulu değilse,
Flutter'ın örnek Android projesi için ürettiği `example/android/gradlew`
(`gradlew.bat`) aynı `-p` ve `-PflutterSdk` seçenekleriyle kullanılabilir.
Bu wrapper dosyaları bu deponun Git çıktısına dahil değildir; temiz klonda
yerel Gradle kurulumunu kullanın.

JUnit XML ve HTML raporları `build/test-results/test` ve
`build/reports/tests/test` altında üretilir; Git'e dahil edilmez.
Yalnızca yapay kimlik verileri kullanılır. Test sınıfını gerçek cihazdan
alınmış değerlerle beslemeyin.

## Sınırlar

Robolectric API 23, 24, 25, 26, 27, 28, 29, 30 ve 35 ortamlarını sağlar.
Telefon servisi, izin durumu ve Activity bağlantıları Mockito ile denetlenir.
İzin callback'i, config-change ayrılma/yeniden bağlanma ve servis hataları
eklentiye doğrudan gönderilir. Sistem izin penceresine gerçek tıklama,
Flutter engine ile gerçek Activity rotasyonu, modem veya OEM izin politikası
doğrulanmaz. Android 10+ `SecurityException` davranışı simüle edilir; OS
yetkilendirmesinin bağımsız bir testi değildir.

Bu testlerin geçmesi APK/AAR üretimini veya fiziksel donanım erişimini
kanıtlamaz. Tam AGP testi için Android SDK bulunan ortamda:

```sh
cd packages/device_identity/example/android
./gradlew :device_identity:testDebugUnitTest
```

Örnek uygulamanın kanal taklitli ekran testleri ayrıca:

```sh
cd packages/device_identity/example
flutter test
```
