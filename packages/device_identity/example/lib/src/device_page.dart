import 'package:device_identity/device_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key, this.previewMode = false});

  /// Only the separate web simulation entry enables this. Native defaults stay
  /// unchanged; the preview installs an explicit fake platform implementation.
  final bool previewMode;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final plugin = DeviceIdentity();
  AndroidDeviceDetails? info;
  ImeiReport? report;
  String? error;
  String? permissionMessage;
  bool busy = false;

  bool get supported => widget.previewMode ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    if (supported) _load();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      await action();
    } catch (e) {
      if (mounted) error = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _load() => _perform(() async {
    final details = await plugin.getDeviceInfo();
    if (mounted) info = details;
  });

  Future<void> _readImei() => _perform(() async {
    // Sensitive identifiers are read only after the user's explicit tap.
    final result = await plugin.getImei();
    if (mounted) report = result;
  });

  Future<void> _requestPermission() => _perform(() async {
    final permission = await plugin.requestPhonePermission();
    if (!mounted) return;
    permissionMessage = permission.message;
    if (permission.status == PhonePermissionStatus.granted) {
      final result = await plugin.getImei();
      if (mounted) report = result;
    }
  });

  @override
  Widget build(BuildContext context) {
    final details = info;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.previewMode ? 'Cihaz Bilgisi · SİMÜLASYON' : 'Cihaz Bilgisi'),
        actions: [
          IconButton(
            tooltip: 'Cihaz bilgilerini yenile',
            onPressed: !supported || busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Cihazını tanı.', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(widget.previewMode
                ? 'ÖRNEK VERİLER — gerçek Android emülatörü değildir. '
                  'Bu ekranda telefonuna ait bilgiler veya gerçek IMEI okunmaz.'
                : 'Bilgiler Android’den okunur. IMEI otomatik alınmaz; hiçbir bilgi kaydedilmez veya sunucuya gönderilmez.'),
            const SizedBox(height: 20),
            if (!supported)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Bu paket yalnızca Android cihazda çalışır. Tarayıcı ve iOS üzerinden IMEI okunamaz.'),
                ),
              ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(error!),
                ),
              ),
            if (details != null) ...[
              const SizedBox(height: 12),
              _section('Donanım', [
                _row('Üretici', details.manufacturer),
                _row('Marka', details.brand),
                _row('Model', details.model),
                _row('Cihaz kodu', details.device),
                _row('Ürün kodu', details.product),
                _row('Donanım', details.hardware),
                _row('CPU mimarileri', details.supportedAbis.join(', ')),
                _row('Telefon modemi', details.hasTelephony ? 'Var' : 'Yok'),
              ]),
              _section('Android', [
                _row('Sürüm', details.androidVersion),
                _row('API seviyesi', '${details.sdkInt}'),
                _row('Güvenlik yaması', details.securityPatch?.isNotEmpty == true
                    ? details.securityPatch! : 'Android tarafından sağlanmadı'),
              ]),
              _section('Bellek ve depolama', [
                _row('Sistemin gördüğü toplam RAM', _gib(details.totalRamBytes)),
                _row('Dahili veri bölümü toplamı', _gib(details.totalStorageBytes)),
                _row('Dahili veri bölümü boş alanı', _gib(details.availableStorageBytes)),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Bu değerler işletim sisteminin raporladığı kapasitedir; kutu üzerinde yazan kapasiteden farklı olabilir.'),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            _section('IMEI', [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Android 10 ve sonrasında normal uygulamalar IMEI okuyamaz. '
                  'Telefon izni tek başına bu kısıtlamayı kaldırmaz. '
                  'Erişim yoksa Ayarlar > Telefon hakkında ekranından kontrol edin.',
                ),
              ),
              if (report != null) ...[
                _row('Durum', _status(report!.status)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(report!.message),
                ),
                for (final entry in report!.entries)
                  _row(
                    'Modem ${entry.slotIndex + 1}',
                    entry.imei ?? '${_status(entry.status)}\n${entry.message}',
                  ),
              ],
              if (permissionMessage != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(permissionMessage!),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: !supported || busy ? null : _readImei,
                      icon: const Icon(Icons.sim_card_outlined),
                      label: const Text('IMEI bilgisini oku'),
                    ),
                    if (details != null && details.sdkInt < 29 && details.hasTelephony)
                      OutlinedButton(
                        onPressed: busy ? null : _requestPermission,
                        child: const Text('Telefon izni ver ve oku'),
                      ),
                  ],
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ...children,
      ],
    ),
  );

  Widget _row(String name, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(value.isEmpty ? 'Android tarafından sağlanmadı' : value),
      ],
    ),
  );

  String _gib(int bytes) => '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';

  String _status(ImeiStatus status) => switch (status) {
    ImeiStatus.available => 'Okundu',
    ImeiStatus.permissionRequired => 'Telefon izni gerekli',
    ImeiStatus.restricted => 'Android erişimi kısıtlıyor',
    ImeiStatus.unavailable => 'IMEI sağlanmadı',
    ImeiStatus.noTelephony => 'Telefon modemi yok',
  };
}
