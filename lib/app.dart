import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'state/ui_state.dart';

/// Root widget: Fluent theme (dark by default) plus go_router.
class ItdmpApp extends ConsumerWidget {
  const ItdmpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FluentApp.router(
      title: 'ITDMP',
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeModeProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
