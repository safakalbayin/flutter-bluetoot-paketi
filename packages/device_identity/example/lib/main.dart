import 'package:flutter/material.dart';

import 'src/device_page.dart';

void main() => runApp(const DeviceInfoApp());

class DeviceInfoApp extends StatelessWidget {
  const DeviceInfoApp({super.key, this.home = const DevicePage()});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cihaz Bilgisi',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF145B90)),
    ),
    home: home,
  );
}
