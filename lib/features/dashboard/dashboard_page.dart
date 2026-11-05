import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/malaysia_time.dart';
import '../../data/api/graph_client.dart';
import '../../models/dashboard.dart';
import '../../models/employee.dart';
import '../../routing/app_router.dart';
import '../../shared/layouts/page_frame.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/table_parts.dart';
import '../../state/providers.dart';
import 'dashboard_controller.dart';

/// Which task group is open in the list.
enum _Group {
  pendingAccept('Pending accept', FluentIcons.add_friend),
  startWork('Start work', FluentIcons.play),
  almostDue('Almost due', FluentIcons.clock),
  due('Due', FluentIcons.warning);

  const _Group(this.title, this.icon);
  final String title;
  final IconData icon;
}

/// Task groups and the things that need the person's action.
/// Team Lead, Management and Admin see all tasks. Everyone else sees only
/// the tasks assigned to them.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  _Group _selected = _Group.pendingAccept;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dashboardProvider);
    final employees = ref.watch(activeEmployeesProvider).value;
    final names = <String, String>{
      for (final e in employees ?? const <Employee>[]) e.employeeId: e.name,
    };

    return PageFrame(
      title: 'Dashboard',
      child: data.when(
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => _Failed(
          message: e is GraphException
              ? e.userMessage
              : 'Could not load the dashboard.',
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (d) => _content(context, d, names),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    DashboardData d,
    Map<String, String> names,
  ) {
    final lists = {
      _Group.pendingAccept: d.pendingAccept,
      _Group.startWork: d.startWork,
      _Group.almostDue: d.almostDue,
      _Group.due: d.due,
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                d.viewAll ? 'All tasks' : 'Your tasks',
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              const SizedBox(width: 12),
              Text('Updated ${formatMalaysiaTime(d.loadedAtUtc)} (Malaysia)'),
              const SizedBox(width: 12),
              Button(
                onPressed: () => ref.invalidate(dashboardProvider),
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (d.truncated) ...[
            const InfoBar(
              title: Text('Some lists are very long'),
              content: Text(
                'Only the first part was loaded, so counts may be low. '
                'Open Tasks to see everything.',
              ),
              severity: InfoBarSeverity.warning,
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final g in _Group.values)
                _CountCard(
                  group: g,
                  count: lists[g]!.length,
                  selected: g == _selected,
                  danger: g == _Group.due && lists[g]!.isNotEmpty,
                  onTap: () => setState(() => _selected = g),
                ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, box) {
              final taskPanel = _TaskPanel(
                group: _selected,
                items: lists[_selected]!,
                names: names,
                showAssignee: d.viewAll,
              );
              final alertPanel = _AlertPanel(alerts: d.alerts, names: names);
              if (box.maxWidth >= kWideTableMinWidth) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: taskPanel),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: alertPanel),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [alertPanel, const SizedBox(height: 16), taskPanel],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoBar(
          title: const Text('Could not load the dashboard'),
          content: Text(message),
          severity: InfoBarSeverity.error,
        ),
        const SizedBox(height: 12),
        Button(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.group,
    required this.count,
    required this.selected,
    required this.danger,
    required this.onTap,
  });

  final _Group group;
  final int count;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final accent = danger ? StatusColors.danger : theme.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accent : theme.resources.cardStrokeColorDefault,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(group.icon, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.title, style: theme.typography.bodyStrong),
                  Text(
                    '$count',
                    style: theme.typography.title?.copyWith(
                      color: danger ? StatusColors.danger : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.typography.subtitle)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => RowCard(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      );
}

class _TaskPanel extends StatelessWidget {
  const _TaskPanel({
    required this.group,
    required this.items,
    required this.names,
    required this.showAssignee,
  });

  final _Group group;
  final List<DashboardTask> items;
  final Map<String, String> names;
  final bool showAssignee;

  static const _maxRows = 50;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(_maxRows).toList();
    return _Panel(
      title: '${group.title} (${items.length})',
      trailing: HyperlinkButton(
        onPressed: () => context.go(AppRoutes.tasks),
        child: const Text('Open Tasks'),
      ),
      child: items.isEmpty
          ? const _Empty('Nothing here.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final t in shown)
                  _TaskTile(
                    item: t,
                    assignee: showAssignee
                        ? names[t.task.assignedEmployeeId] ??
                            t.task.assignedEmployeeId
                        : null,
                  ),
                if (items.length > _maxRows)
                  Text('And ${items.length - _maxRows} more in Tasks.'),
              ],
            ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.item, required this.assignee});

  final DashboardTask item;
  final String? assignee;

  @override
  Widget build(BuildContext context) {
    final t = item.task;
    final days = item.daysToDue;
    final (label, color) = days < 0
        ? ('${-days} day${days == -1 ? '' : 's'} late', StatusColors.danger)
        : days == 0
            ? ('Due today', StatusColors.warning)
            : days <= 3
                ? ('In $days day${days == 1 ? '' : 's'}', StatusColors.warning)
                : (formatMalaysiaDate(t.expectedCompletion),
                    StatusColors.neutral);
    final theme = FluentTheme.of(context);
    final detail = [
      t.taskCode,
      ?assignee,
      if (t.companyName.isNotEmpty) t.companyName,
      t.priority.label,
    ].join('  ·  ');

    return RowCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(label: label, color: color),
              const SizedBox(height: 4),
              Text(
                formatMalaysiaDate(t.expectedCompletion),
                style: theme.typography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertPanel extends StatelessWidget {
  const _AlertPanel({required this.alerts, required this.names});

  final List<DashboardAlert> alerts;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Notifications (${alerts.length})',
      child: alerts.isEmpty
          ? const _Empty('Nothing needs your action.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final g in AlertGroup.values)
                  ..._group(context, g),
              ],
            ),
    );
  }

  List<Widget> _group(BuildContext context, AlertGroup group) {
    final items = alerts.where((a) => a.group == group).toList();
    if (items.isEmpty) return const [];
    final theme = FluentTheme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text('${group.label} (${items.length})',
            style: theme.typography.bodyStrong),
      ),
      for (final a in items) _AlertTile(alert: a, names: names),
    ];
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.names});

  final DashboardAlert alert;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final who = alert.employeeId.isEmpty
        ? null
        : names[alert.employeeId] ?? alert.employeeId;
    final (icon, route) = switch (alert.target) {
      AlertTarget.tasks => (FluentIcons.task_list, AppRoutes.tasks),
      AlertTarget.issues => (FluentIcons.bug, AppRoutes.issues),
      AlertTarget.dailyReports => (
          FluentIcons.report_document,
          AppRoutes.dailyReports,
        ),
    };
    return GestureDetector(
      onTap: () => context.go(route),
      child: RowCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: StatusColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.bodyStrong,
                  ),
                  Text(
                    who == null ? alert.action : '$who: ${alert.action}',
                    style: theme.typography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
