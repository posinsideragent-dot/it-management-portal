import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_router.dart';
import '../../services/session_state.dart';
import '../../state/providers.dart';

/// Sidebar plus top bar around every signed-in page.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _mainPaths = [AppRoutes.dashboard, AppRoutes.timeTracker];
  static const _footerPaths = [AppRoutes.settings];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionControllerProvider);
    final userName = session is SessionActive ? session.user.name : '';

    final mainIndex = _mainPaths.indexOf(location);
    final footerIndex = _footerPaths.indexOf(location);
    final selected = mainIndex >= 0
        ? mainIndex
        : (footerIndex >= 0 ? _mainPaths.length + footerIndex : 0);

    return NavigationView(
      // fluent_ui 4.14+ replaced NavigationAppBar with a plain `titleBar` widget.
      titleBar: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('ITDMP  (${config.environment})'),
              const Spacer(),
              Text(userName),
            ],
          ),
        ),
      ),
      paneBodyBuilder: (item, body) => child,
      pane: NavigationPane(
        selected: selected,
        displayMode: PaneDisplayMode.expanded,
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('Dashboard'),
            body: const SizedBox.shrink(),
            onTap: () => context.go(AppRoutes.dashboard),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.timer),
            title: const Text('Time Tracker'),
            body: const SizedBox.shrink(),
            onTap: () => context.go(AppRoutes.timeTracker),
          ),
        ],
        footerItems: [
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('Settings'),
            body: const SizedBox.shrink(),
            onTap: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}
