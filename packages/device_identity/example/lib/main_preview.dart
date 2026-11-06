// Explicit simulation entry. This file is NOT imported by native main.dart.
import 'package:device_identity/device_identity_platform_interface.dart';
import 'package:flutter/material.dart';

import 'main.dart' show DeviceInfoApp;
import 'src/device_page.dart';
import 'src/preview_platform.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final scenario = PreviewScenario.fromKey(Uri.base.queryParameters['scenario']);
  DeviceIdentityPlatform.instance = PreviewDevicePlatform(scenario);
  runApp(const DeviceInfoApp(home: DevicePage(previewMode: true)));
}
