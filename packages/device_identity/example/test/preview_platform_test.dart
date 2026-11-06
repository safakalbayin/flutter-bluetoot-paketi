import 'package:device_identity/device_identity.dart';
import 'package:device_identity/device_identity_platform_interface.dart';
import 'package:device_identity_example/main.dart';
import 'package:device_identity_example/src/device_page.dart';
import 'package:device_identity_example/src/preview_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown browser scenario defaults to restricted access', () {
    expect(PreviewScenario.fromKey(null), PreviewScenario.restricted);
    expect(PreviewScenario.fromKey('invalid'), PreviewScenario.restricted);
  });

  test('acceptance scenario requires explicit permission then returns DEMO text', () async {
    final device = DeviceIdentity(platform: PreviewDevicePlatform(PreviewScenario.grant));
    expect((await device.getImei()).status, ImeiStatus.permissionRequired);
    expect((await device.requestPhonePermission()).status, PhonePermissionStatus.granted);
    final report = await device.getImei();
    expect(report.status, ImeiStatus.available);
    expect(report.entries.length, 2);
    expect(report.entries.first.imei, startsWith('DEMO-IMEI-'));
    expect(report.entries.first.imei, contains('gerçek numara değil'));
  });

  test('denial scenario does not reveal sample IMEI', () async {
    final device = DeviceIdentity(platform: PreviewDevicePlatform(PreviewScenario.deny));
    expect((await device.requestPhonePermission()).status, PhonePermissionStatus.denied);
    final report = await device.getImei();
    expect(report.status, ImeiStatus.permissionRequired);
    expect(report.entries, isEmpty);
  });

  test('modern Android scenario remains restricted', () async {
    final device = DeviceIdentity(platform: PreviewDevicePlatform(PreviewScenario.restricted));
    expect((await device.getDeviceInfo()).sdkInt, 29);
    expect((await device.requestPhonePermission()).status, PhonePermissionStatus.restricted);
    expect((await device.getImei()).status, ImeiStatus.restricted);
  });

  test('modemless scenario cannot provide IMEI', () async {
    final device = DeviceIdentity(platform: PreviewDevicePlatform(PreviewScenario.noModem));
    expect((await device.getDeviceInfo()).hasTelephony, false);
    expect((await device.getImei()).status, ImeiStatus.noTelephony);
  });

  for (final scenario in PreviewScenario.values) {
    testWidgets('actual Flutter screen handles ${scenario.key}', (tester) async {
      // These tests verify scenario outcomes, not nested SelectableText scroll
      // behavior. Keep the whole form visible while asynchronous rows appear.
      tester.view.physicalSize = const Size(600, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final original = DeviceIdentityPlatform.instance;
      addTearDown(() => DeviceIdentityPlatform.instance = original);
      DeviceIdentityPlatform.instance = PreviewDevicePlatform(scenario);
      await tester.pumpWidget(
        const DeviceInfoApp(home: DevicePage(previewMode: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cihaz Bilgisi · SİMÜLASYON'), findsOneWidget);
      final read = find.text('IMEI bilgisini oku');
      await tester.scrollUntilVisible(
        read, 500, scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(read);
      await tester.pumpAndSettle();
      if (scenario == PreviewScenario.grant || scenario == PreviewScenario.deny) {
        final permission = find.text('Telefon izni ver ve oku');
        await tester.ensureVisible(permission);
        await tester.tap(permission);
        await tester.pumpAndSettle();
        final result = scenario == PreviewScenario.grant
            ? find.text('DEMO-IMEI-1 · gerçek numara değil')
            : find.textContaining('telefon izni reddedildi');
        await tester.scrollUntilVisible(
          result, -200, scrollable: find.byType(Scrollable).first,
        );
        expect(result, findsOneWidget);
      } else {
        final result = scenario == PreviewScenario.restricted
            ? find.text('Android erişimi kısıtlıyor')
            : find.text('Telefon modemi yok');
        await tester.scrollUntilVisible(
          result, -200, scrollable: find.byType(Scrollable).first,
        );
        expect(result, findsOneWidget);
        expect(find.text('Telefon izni ver ve oku'), findsNothing);
      }
    });
  }
}
