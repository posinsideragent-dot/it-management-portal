import 'package:flutter/material.dart';

import 'core/configuration/app_config.dart';
import 'spike/spike_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ItdmpApp());
}

/// Phase 1 entry point. Step 6 replaces the home page with the real shell
/// (Fluent UI, Riverpod, go_router).
class ItdmpApp extends StatelessWidget {
  const ItdmpApp({super.key});

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
