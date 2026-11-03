import 'package:flutter/material.dart';

import 'core/configuration/app_config.dart';
import 'spike/spike_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SpikeApp());
}

/// Sign-in spike entry point (Phase 1, step 5). Run with:
///   flutter run -d windows -t lib/spike_main.dart
/// The real app starts from lib/main.dart.
class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITDMP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const SpikePage(config: AppConfig.dev),
    );
  }
}
