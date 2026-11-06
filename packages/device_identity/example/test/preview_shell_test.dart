import 'package:device_identity/device_identity.dart';
import 'package:device_identity/device_identity_platform_interface.dart';
import 'package:device_identity_example/main.dart';
import 'package:device_identity_example/src/preview_platform.dart';
import 'package:device_identity_example/src/preview_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<T> finish<T>(WidgetTester tester, Future<T> pending) async {
  await tester.pump(const Duration(milliseconds: 200));
  return pending;
}

void main() {
  test('standalone links retain artifact base and selected scenario', () {
    final uri = standaloneUri(
      PreviewScenario.deny,
      Uri.parse('https://example.test/device-identity/?scenario=old'),
    );
    expect(uri.path, '/device-identity/');
    expect(uri.queryParameters,
        {'screen': 'device', 'scenario': 'android9-deny'});
  });

  testWidgets('Dart controls switch scenarios and reset granted permission',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = DeviceIdentityPlatform.instance;
    addTearDown(() => DeviceIdentityPlatform.instance = original);
    final key = GlobalKey<PreviewShellState>();
    Uri? opened;
    await tester.pumpWidget(DeviceInfoApp(
      home: PreviewShell(key: key, onOpenStandalone: (uri) => opened = uri),
    ));
    await tester.pumpAndSettle();
    expect(key.currentState!.scenario, PreviewScenario.restricted);
    expect(find.text('SİMÜLASYON — örnek veriler'), findsOneWidget);
    for (final scenario in PreviewScenario.values) {
      expect(find.text(scenarioInfo(scenario).title), findsOneWidget);
    }
    await tester.tap(find.text('Android 9 — izin kabul'));
    await tester.pumpAndSettle();
    expect(key.currentState!.scenario, PreviewScenario.grant);
    await finish(tester, DeviceIdentity().requestPhonePermission());
    expect((await finish(tester, DeviceIdentity().getImei())).status,
        ImeiStatus.available);
    await tester.tap(find.text('Senaryoyu sıfırla'));
    await tester.pumpAndSettle();
    expect((await finish(tester, DeviceIdentity().getImei())).status,
        ImeiStatus.permissionRequired);
    await tester.tap(find.text('Ayrı sekmede aç'));
    expect(opened!.queryParameters,
        {'screen': 'device', 'scenario': 'android9-grant'});
    await tester.tap(find.text('Android 9 — izin reddi'));
    await tester.pumpAndSettle();
    expect((await finish(tester, DeviceIdentity().requestPhonePermission())).status,
        PhonePermissionStatus.denied);
    await tester.tap(find.text('Telefon modemi yok'));
    await tester.pumpAndSettle();
    expect((await finish(tester, DeviceIdentity().getImei())).status,
        ImeiStatus.noTelephony);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dart preview fits a narrow viewport without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = DeviceIdentityPlatform.instance;
    addTearDown(() => DeviceIdentityPlatform.instance = original);
    await tester.pumpWidget(
        const DeviceInfoApp(home: PreviewShell()));
    await tester.pumpAndSettle();
    expect(find.text('SİMÜLASYON — örnek veriler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
