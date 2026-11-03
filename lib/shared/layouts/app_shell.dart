import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/app_router.dart';
import '../../services/session_state.dart';
import '../../state/providers.dart';
import '../../state/ui_state.dart';

/// Sidebar plus top bar around every signed-in page.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _mainPaths = [AppRoutes.dashboard, AppRoutes.employees, AppRoutes.tasks, AppRoutes.timeTracker];
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

    final expanded = ref.watch(sidebarExpandedProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return LayoutBuilder(builder: (context, constraints) {
      // Narrow windows always show the icon-only sidebar.
      final narrow = constraints.maxWidth < _narrowWidth;
      final showLabels = expanded && !narrow;
      return _buildView(
        context, ref,
        showLabels: showLabels,
        isDark: isDark,
        environment: config.environment,
        userName: userName,
        selected: selected,
      );
    });
  }

  static const _narrowWidth = 900.0;

  Widget _buildView(
    BuildContext context,
    WidgetRef ref, {
    required bool showLabels,
    required bool isDark,
    required String environment,
    required String userName,
    required int selected,
  }) {
    return NavigationView(
      // fluent_ui 4.14+ replaced NavigationAppBar with a plain `titleBar` widget.
      titleBar: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Tooltip(
                message: showLabels ? 'Collapse menu' : 'Expand menu',
                child: IconButton(
                  icon: const Icon(FluentIcons.global_nav_button),
                  onPressed: ref.read(sidebarExpandedProvider.notifier).toggle,
                ),
              ),
              const SizedBox(width: 8),
              Text('ITDMP', style: FluentTheme.of(context).typography.bodyStrong),
              const SizedBox(width: 8),
              Text('($environment)'),
              const Spacer(),
              Tooltip(
                message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                child: IconButton(
                  icon: Icon(isDark ? FluentIcons.sunny : FluentIcons.clear_night),
                  onPressed: ref.read(themeModeProvider.notifier).toggle,
                ),
              ),
              const SizedBox(width: 8),
              Text(userName),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      paneBodyBuilder: (item, body) => child,
      pane: NavigationPane(
        selected: selected,
        displayMode:
            showLabels ? PaneDisplayMode.expanded : PaneDisplayMode.compact,
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('Dashboard'),
            body: const SizedBox.shrink(),
            onTap: () => context.go(AppRoutes.dashboard),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.people),
            title: const Text('Employees'),
            body: const SizedBox.shrink(),
            onTap: () => context.go(AppRoutes.employees),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.task_list),
            title: const Text('Tasks'),
            body: const SizedBox.shrink(),
            onTap: () => context.go(AppRoutes.tasks),
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
