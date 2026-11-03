import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';

/// Root widget: Fluent theme plus go_router.
class ItdmpApp extends ConsumerWidget {
  const ItdmpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FluentApp.router(
      title: 'ITDMP',
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
