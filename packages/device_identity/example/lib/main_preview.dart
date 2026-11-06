// Explicit simulation entry. This file is NOT imported by native main.dart.
import 'package:flutter/material.dart';

import 'main.dart' show DeviceInfoApp;
import 'src/preview_platform.dart';
import 'src/preview_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final query = Uri.base.queryParameters;
  final scenario = PreviewScenario.fromKey(query['scenario']);
  final home = query['screen'] == 'device'
      ? PreviewDeviceOnly(scenario: scenario)
      : PreviewShell(initialScenario: scenario);
  runApp(DeviceInfoApp(home: home));
}
