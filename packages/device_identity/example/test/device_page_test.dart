import 'dart:async';

import 'package:device_identity_example/src/device_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.deviceidentity/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  late int sdk;
  late bool telephony;
  late String permissionStatus;
  late Map<String, Object?> report;
  Completer<Object?>? pendingPermission;

  setUp(() {
    calls = [];
    sdk = 28;
    telephony = true;
    permissionStatus = 'denied';
    pendingPermission = null;
    report = {
      'status': 'permissionRequired',
      'message': 'İzin gerekli test mesajı',
      'entries': <Object?>[],
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'getDeviceInfo':
          return {
            'manufacturer': 'Test',
            'brand': 'Test',
            'model': 'Test',
            'device': 'Test',
            'product': 'Test',
            'hardware': 'Test',
            'androidVersion': 'Test',
            'sdkInt': sdk,
            'securityPatch': null,
            'supportedAbis': ['test'],
            'totalRamBytes': 1024,
            'totalStorageBytes': 2048,
            'availableStorageBytes': 1024,
            'hasTelephony': telephony,
          };
        case 'requestPhonePermission':
          if (pendingPermission != null) {
            return await pendingPermission!.future;
          }
          return {
            'status': permissionStatus,
            'message': 'İzin sonucu: $permissionStatus',
          };
        case 'getImei':
          return report;
        default:
          throw MissingPluginException();
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void androidTest(String name, WidgetTesterCallback callback) {
    testWidgets(name, callback,
        variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  Future<void> showPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DevicePage()));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String label) async {
    final button = find.text(label);
    await tester.scrollUntilVisible(button, 300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ).first);
    await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final button = find.text(label);
    await reveal(tester, label);
    await tester.tap(button);
    await tester.pump();
    if (pendingPermission == null || pendingPermission!.isCompleted) {
      await tester.pumpAndSettle();
    }
  }

  androidTest('opening and refreshing never collect IMEI', (tester) async {
    await showPage(tester);
    expect(calls, ['getDeviceInfo']);
    await tester.tap(find.byTooltip('Cihaz bilgilerini yenile'));
    await tester.pumpAndSettle();
    expect(calls, ['getDeviceInfo', 'getDeviceInfo']);
  });

  for (final api in [23, 24, 25, 26, 27, 28]) {
    androidTest('API $api denial does not read; explicit retry grant reads once',
        (tester) async {
      sdk = api;
      await showPage(tester);
      await tap(tester, 'Telefon izni ver ve oku');
      expect(calls, ['getDeviceInfo', 'requestPhonePermission']);
      expect(find.text('İzin sonucu: denied'), findsOneWidget);
      permissionStatus = 'granted';
      report = {
        'status': 'available',
        'message': 'Sentetik modem sonucu',
        'entries': [
          {
            'slotIndex': 0,
            'status': 'available',
            'message': 'Sentetik değer',
            // Invented fixture, not obtained from a device.
            'imei': '123456789012345',
          },
        ],
      };
      await tap(tester, 'Telefon izni ver ve oku');
      expect(calls, [
        'getDeviceInfo',
        'requestPhonePermission',
        'requestPhonePermission',
        'getImei',
      ]);
      expect(find.text('Okundu'), findsOneWidget);
      expect(find.text('Modem 1'), findsOneWidget);
    });
  }

  androidTest('rotation while permission is pending neither repeats nor loses it',
      (tester) async {
    pendingPermission = Completer<Object?>();
    await showPage(tester);
    await tap(tester, 'Telefon izni ver ve oku');
    expect(calls, ['getDeviceInfo', 'requestPhonePermission']);
    // Inserting the busy indicator can recycle this off-screen ListView child.
    await reveal(tester, 'Telefon izni ver ve oku');
    final permissionButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Telefon izni ver ve oku'),
    );
    expect(permissionButton.onPressed, isNull);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump();
    expect(calls, ['getDeviceInfo', 'requestPhonePermission']);
    pendingPermission!.complete({
      'status': 'granted',
      'message': 'Döndürmeden sonra izin verildi',
    });
    await tester.pumpAndSettle();
    expect(calls, ['getDeviceInfo', 'requestPhonePermission', 'getImei']);
    await reveal(tester, 'Telefon izni ver ve oku');
    expect(
      tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Telefon izni ver ve oku'),
      ).onPressed,
      isNotNull,
    );
  });

  for (final api in [29, 30, 35]) {
    androidTest('API $api restriction has no permission button or automatic read',
        (tester) async {
      sdk = api;
      report = {
        'status': 'restricted',
        'message': 'Android erişim kısıtlaması test mesajı',
        'entries': <Object?>[],
      };
      await showPage(tester);
      expect(calls, ['getDeviceInfo']);
      expect(find.text('Telefon izni ver ve oku'), findsNothing);
      await tap(tester, 'IMEI bilgisini oku');
      expect(calls, ['getDeviceInfo', 'getImei']);
      expect(find.text('Android erişimi kısıtlıyor'), findsOneWidget);
      expect(find.text('Android erişim kısıtlaması test mesajı'), findsOneWidget);
    });
  }

  androidTest('no modem hides permission and shows explicit noTelephony result',
      (tester) async {
    telephony = false;
    report = {
      'status': 'noTelephony',
      'message': 'Modem yok test mesajı',
      'entries': <Object?>[],
    };
    await showPage(tester);
    expect(find.text('Telefon izni ver ve oku'), findsNothing);
    await tap(tester, 'IMEI bilgisini oku');
    expect(calls, ['getDeviceInfo', 'getImei']);
    expect(find.text('Telefon modemi yok'), findsOneWidget);
  });

  androidTest('multiple modems show individual partial-access results',
      (tester) async {
    report = {
      'status': 'available',
      'message': 'Kısmi erişim test mesajı',
      'entries': [
        {
          'slotIndex': 0,
          'status': 'available',
          'message': 'Sentetik değer',
          'imei': '123456789012345',
        },
        {
          'slotIndex': 1,
          'status': 'restricted',
          'message': 'İkinci modem kısıtlı',
          'imei': null,
        },
      ],
    };
    await showPage(tester);
    await tap(tester, 'IMEI bilgisini oku');
    expect(find.text('Modem 1'), findsOneWidget);
    expect(find.text('Modem 2'), findsOneWidget);
    expect(find.text('Android erişimi kısıtlıyor\nİkinci modem kısıtlı'),
        findsOneWidget);
    expect(calls, ['getDeviceInfo', 'getImei']);
  });

  androidTest('disposing during permission request never triggers an IMEI read',
      (tester) async {
    pendingPermission = Completer<Object?>();
    await showPage(tester);
    await tap(tester, 'Telefon izni ver ve oku');
    await tester.pumpWidget(const SizedBox());
    pendingPermission!.complete({'status': 'granted', 'message': 'Test'});
    await tester.pumpAndSettle();
    expect(calls, ['getDeviceInfo', 'requestPhonePermission']);
    expect(tester.takeException(), isNull);
  });
}
