# Blooted örnek uygulaması

`blooted` paketini `path: ../` bağımlılığıyla kullanan gerçek Flutter Android
uygulaması. Mock veri veya tarayıcı Bluetooth simülasyonu içermez.

## Burada görüntüleme

Replit'teki **Blooted — Flutter Önizleme** aynı `lib/main.dart` ekranını
Flutter web derlemesi olarak gösterir. Bu yalnızca arayüz önizlemesidir;
donanım düğmeleri tarayıcıda devre dışıdır. BLE paketine web desteği eklemez.
Tarama ve GATT işlemleri için aşağıdaki Android akışını kullanın.

```sh
flutter pub get
flutter devices
flutter run -d <android-cihaz-id>
```

1. Telefonda Bluetooth'u açın.
2. Uygulamada **İzin iste** düğmesine basın.
3. Android 6–11'de konum servislerini açın.
4. **Cihaz tara** düğmesine basıp BLE cihazınızda **Bağlan** seçin.
5. Servisi genişletip desteklenen okuma / yazma / bildirim işlemini seçin.
6. Veri göndermek için 1–20 baytlık hex veri girin: `01 A0 FF`.

Uygulama bağlantıdan sonra servisleri kendisi keşfeder. Arka plana geçince
taramayı durdurup bağlantıyı keser; otomatik yeniden bağlanmaz.

- `lib/main.dart`: ekran ve uygulama teması.
- `lib/src/ble_controller.dart`: uygulamaya ait bağlantı ve yaşam döngüsü kararları.
- `lib/src/characteristic_tile.dart`: GATT işlemleri için kontroller.

Destek ve sınırlar için [paket dokümanına](../README.md) bakın.
