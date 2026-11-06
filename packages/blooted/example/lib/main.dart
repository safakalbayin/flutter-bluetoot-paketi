import 'package:flutter/material.dart';

import 'src/ble_controller.dart';
import 'src/characteristic_tile.dart';

void main() => runApp(const BlootedApp());

class BlootedApp extends StatelessWidget {
  const BlootedApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Blooted',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF006B67),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const BluetoothPage(),
  );
}

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  late final BleController controller;

  @override
  void initState() {
    super.initState();
    controller = BleController()..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final state = c.adapter;
      return Scaffold(
        appBar: AppBar(
          title: const Text('blooted / BLE'),
          actions: [
            IconButton(
              tooltip: 'Durumu yenile',
              onPressed: !c.nativeAvailable || c.busy ? null : c.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Kontrol uygulamada.', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Gerçek Android BLE bağlantısı · Platform Channel\n'
                'Otomatik bağlantı veya arka plan taraması yok.',
              ),
              const SizedBox(height: 20),
              if (!c.nativeAvailable)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Flutter arayüz önizlemesi\n\n'
                            'Bu, örnek uygulamanın gerçek Flutter ekranıdır. '
                            'Bluetooth işlemleri yalnızca Android cihazda çalışır; '
                            'tarayıcıda donanım düğmeleri devre dışıdır. '
                            'Sahte cihaz veya bağlantı gösterilmez.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(!c.nativeAvailable ? 'Arayüz önizlemesi' :
                      state == null ? 'Durum bekleniyor' :
                      !state.supported ? 'BLE desteklenmiyor' :
                      state.enabled ? 'Bluetooth açık' : 'Bluetooth kapalı')),
                  Chip(label: Text(!c.nativeAvailable ? 'Android cihaz gerekli' :
                      state?.permissionsGranted == true ? 'İzinler hazır' : 'İzin gerekli')),
                  if (state?.locationEnabled == false)
                    const Chip(label: Text('Konum servislerini açın')),
                  if (c.scanning) const Chip(label: Text('Taranıyor…')),
                ],
              ),
              if (c.error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(c.error!),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: !c.nativeAvailable || c.busy ? null : c.requestPermissions,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('İzin iste'),
                  ),
                  FilledButton.icon(
                    onPressed: !c.nativeAvailable || c.busy || c.connectedId != null
                        ? null
                        : c.scanning ? c.stopScan : c.scan,
                    icon: Icon(c.scanning ? Icons.stop : Icons.radar),
                    label: Text(c.scanning ? 'Taramayı durdur' : 'Cihaz tara · 10 sn'),
                  ),
                ],
              ),
              if (c.busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 24),
              if (c.connectedId != null) ...[
                Text('Bağlı cihaz', style: Theme.of(context).textTheme.titleLarge),
                SelectableText(c.connectedId!),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: c.busy ? null : c.discover,
                      child: const Text('Servisleri keşfet'),
                    ),
                    TextButton(
                      onPressed: c.disconnect,
                      child: const Text('Bağlantıyı kes'),
                    ),
                  ],
                ),
                for (final service in c.services)
                  Card(
                    child: ExpansionTile(
                      title: const Text('GATT servisi'),
                      subtitle: Text(service.uuid),
                      children: [
                        for (final characteristic in service.characteristics)
                          CharacteristicTile(
                            key: ValueKey('${service.uuid}/${characteristic.uuid}'),
                            controller: c,
                            serviceUuid: service.uuid,
                            characteristic: characteristic,
                          ),
                      ],
                    ),
                  ),
              ] else ...[
                Text('Yakındaki cihazlar', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (c.devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Henüz cihaz yok. Bluetooth’u açın, izin verin ve taramayı başlatın.\n'
                      'Yalnızca BLE yayını yapan cihazlar görünür; klasik Bluetooth cihazları listelenmez.',
                    ),
                  ),
                for (final device in c.devices)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(device.name.isEmpty ? 'İsimsiz BLE cihazı' : device.name),
                      subtitle: Text('${device.id}\n${device.rssi} dBm'),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: c.busy ? null : () => c.connect(device.id),
                        child: const Text('Bağlan'),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('İşlem günlüğü'),
                subtitle: Text('${c.logs.length} kayıt · en yeni üstte'),
                children: [
                  if (c.logs.isEmpty) const Text('Henüz işlem yok.'),
                  for (final entry in c.logs)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SelectableText(entry, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
