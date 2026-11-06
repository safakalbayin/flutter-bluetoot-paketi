// Simulation-only shell. Never imported by native main.dart.
import 'package:device_identity/device_identity_platform_interface.dart';
import 'package:flutter/material.dart';

import 'device_page.dart';
import 'open_tab.dart';
import 'preview_platform.dart';

const _ink = Color(0xFF14283A);
const _tape = Color(0xFFE9A23B);
const _paper = Color(0xFFF6F1E7);

class ScenarioInfo {
  const ScenarioInfo(this.code, this.title, this.steps, this.expect, this.tone);
  final String code;
  final String title;
  final List<String> steps;
  final String expect;
  final Color tone;
}

const _readStep = "'IMEI bilgisini oku' düğmesine tıklayın.";
const _permStep = "'Telefon izni ver ve oku' düğmesine tıklayın.";

ScenarioInfo scenarioInfo(PreviewScenario s) => switch (s) {
  PreviewScenario.grant => const ScenarioInfo('API 28', 'Android 9 — izin kabul',
      [_readStep, _permStep],
      'İzin verilmiş sayılır; örnek değer DEMO-IMEI-1 gösterilir. Gerçek işletim sistemi istemi açılmaz.',
      Color(0xFF3B7A57)),
  PreviewScenario.deny => const ScenarioInfo('API 28', 'Android 9 — izin reddi',
      [_readStep, _permStep],
      'İzin reddedilmiş sayılır; IMEI gösterilmez, ret mesajı görünür.', _tape),
  PreviewScenario.restricted => const ScenarioInfo('API 29+', 'Android 10+ — IMEI kısıtlı',
      [_readStep],
      'Android 10 ve sonrası üçüncü taraf uygulamalara IMEI vermez; kısıtlama açıklaması görünür.',
      Color(0xFFB3412E)),
  PreviewScenario.noModem => const ScenarioInfo('Modem yok', 'Telefon modemi yok',
      [_readStep],
      'Cihazda telefon modemi olmadığı için IMEI bulunmadığı bildirilir.',
      Color(0xFF6B7280)),
};

/// URL that shows only the labelled device screen for [scenario].
Uri standaloneUri(PreviewScenario scenario, [Uri? base]) =>
    (base ?? Uri.base).replace(queryParameters: {
      'screen': 'device',
      'scenario': scenario.key,
    });

class SimulationBanner extends StatelessWidget {
  const SimulationBanner({super.key});
  @override
  Widget build(BuildContext context) => Material(
    color: _tape,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: _paper,
              child: const Text('SİMÜLASYON — örnek veriler',
                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: _ink, letterSpacing: 1)),
            ),
            const Text('Gerçek Android emülatörü değildir; gerçek cihaz bilgisi veya IMEI okunmaz.',
                style: TextStyle(fontWeight: FontWeight.w600, color: _ink)),
          ],
        ),
      ),
    ),
  );
}

/// Standalone view: banner + labelled DevicePage only (screen=device).
class PreviewDeviceOnly extends StatefulWidget {
  const PreviewDeviceOnly({super.key, required this.scenario});
  final PreviewScenario scenario;
  @override
  State<PreviewDeviceOnly> createState() => _PreviewDeviceOnlyState();
}

class _PreviewDeviceOnlyState extends State<PreviewDeviceOnly> {
  @override
  void initState() {
    super.initState();
    DeviceIdentityPlatform.instance = PreviewDevicePlatform(widget.scenario);
  }

  @override
  Widget build(BuildContext context) => const Column(children: [
    SimulationBanner(),
    Expanded(child: DevicePage(previewMode: true)),
  ]);
}

class PreviewShell extends StatefulWidget {
  const PreviewShell({super.key, this.initialScenario = PreviewScenario.restricted, this.onOpenStandalone});
  final PreviewScenario initialScenario;
  /// Optional override for tests; defaults to opening a new browser tab.
  final void Function(Uri uri)? onOpenStandalone;
  @override
  State<PreviewShell> createState() => PreviewShellState();
}

class PreviewShellState extends State<PreviewShell> {
  late PreviewScenario scenario;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    scenario = widget.initialScenario;
    _install();
  }

  // Install a fresh fake platform BEFORE the keyed DevicePage is built.
  void _install() => DeviceIdentityPlatform.instance = PreviewDevicePlatform(scenario);

  void choose(PreviewScenario s) => setState(() {
    scenario = s;
    generation++;
    _install();
  });

  void reset() => choose(scenario);

  void _openStandalone() {
    final uri = standaloneUri(scenario);
    final custom = widget.onOpenStandalone;
    if (custom != null) return custom(uri);
    if (!openInNewTab(uri.toString())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bağlantı: $uri')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = _Phone(child: DevicePage(key: ValueKey('device-$generation'), previewMode: true));
    final controls = _Controls(
      selected: scenario,
      onSelect: choose,
      onReset: reset,
      onOpen: _openStandalone,
    );
    return Scaffold(
      backgroundColor: _paper,
      body: Column(children: [
        const SimulationBanner(),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 860;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: controls),
                          const SizedBox(width: 32),
                          phone,
                        ])
                      : Column(children: [controls, const SizedBox(height: 24), phone]),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.selected, required this.onSelect, required this.onReset, required this.onOpen});
  final PreviewScenario selected;
  final ValueChanged<PreviewScenario> onSelect;
  final VoidCallback onReset;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final info = scenarioInfo(selected);
    final t = Theme.of(context).textTheme;
    const mono = TextStyle(fontFamily: 'monospace', letterSpacing: 1.2, fontSize: 12);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DEVICE IDENTITY · İZİN DAVRANIŞI', style: mono.copyWith(color: const Color(0xFF145B90), fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Bir senaryo seçin, Flutter ekranında deneyin.',
          style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 16),
      Semantics(
        label: 'Senaryo',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in PreviewScenario.values)
            _ScenarioButton(scenario: s, active: s == selected, onTap: () => onSelect(s)),
        ]),
      ),
      const SizedBox(height: 16),
      Card(
        key: ValueKey('info-${selected.key}'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YAPILACAKLAR', style: mono.copyWith(color: Colors.black54)),
            const SizedBox(height: 8),
            for (var i = 0; i < info.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${i + 1}. ${info.steps[i]}'),
              ),
            const SizedBox(height: 10),
            Text('BEKLENEN SONUÇ', style: mono.copyWith(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(info.expect),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: onReset, icon: const Icon(Icons.restart_alt), label: const Text('Senaryoyu sıfırla')),
        OutlinedButton.icon(onPressed: onOpen, icon: const Icon(Icons.open_in_new), label: const Text('Ayrı sekmede aç')),
      ]),
    ]);
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({required this.scenario, required this.active, required this.onTap});
  final PreviewScenario scenario;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = scenarioInfo(scenario);
    final fg = active ? _paper : _ink;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: active,
      button: true,
      child: SizedBox(
        width: 250,
        child: Material(
          color: active ? const Color(0xFF145B90) : Colors.white.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: active ? const Color(0xFF145B90) : const Color(0xFFD8CFBF)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: info.tone, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(info.title, style: TextStyle(fontWeight: FontWeight.w700, color: fg))),
                ]),
                const SizedBox(height: 2),
                Text('${info.code} · ${scenario.key}',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: fg.withValues(alpha: 0.75))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Phone extends StatelessWidget {
  const _Phone({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.sizeOf(context).height * 0.78).clamp(420.0, 640.0);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(32)),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(height: h, child: child),
          ),
          Positioned(
            top: 4, left: 0, right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _tape, borderRadius: BorderRadius.circular(99)),
                  child: const Text('SİMÜLASYON',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: _ink)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
