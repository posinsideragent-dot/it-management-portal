import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/malaysia_time.dart';
import '../../models/employee.dart';
import '../../models/issue.dart';
import '../../models/task_enums.dart';
import '../../shared/layouts/page_frame.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/table_parts.dart';
import '../../state/providers.dart';
import 'issue_detail_dialog.dart';
import 'issue_form_dialog.dart';
import 'issue_list_controller.dart';
import 'issue_list_state.dart';

/// Technical issues. Anyone can report one. Team Leads assign them.
class IssueListPage extends ConsumerWidget {
  const IssueListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(issueListControllerProvider);
    final controller = ref.read(issueListControllerProvider.notifier);

    return PageFrame(
      title: 'Issues',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextBox(
                  placeholder: 'Search loaded rows',
                  onChanged: controller.setSearch,
                ),
              ),
              ComboBox<String>(
                value: state.statusFilter?.label ?? _all,
                items: [
                  const ComboBoxItem<String>(
                    value: _all,
                    child: Text('All statuses'),
                  ),
                  for (final s in IssueStatus.values)
                    ComboBoxItem<String>(value: s.label, child: Text(s.label)),
                ],
                onChanged: (v) => controller.setStatusFilter(
                  v == null || v == _all ? null : IssueStatus.tryParse(v),
                ),
              ),
              ToggleSwitch(
                checked: state.mineOnly,
                onChanged: controller.setMineOnly,
                content: const Text('Assigned to me'),
              ),
              Button(onPressed: controller.load, child: const Text('Refresh')),
              FilledButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const IssueFormDialog(),
                ),
                child: const Text('Report issue'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _Body(state: state)),
        ],
      ),
    );
  }

  static const _all = '__all__';
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final IssueListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(issueListControllerProvider.notifier);

    switch (state.status) {
      case IssueLoadStatus.loading:
        return const Center(child: ProgressRing());
      case IssueLoadStatus.failed:
        return Align(
          alignment: Alignment.topLeft,
          child: InfoBar(
            title: const Text('Could not load issues'),
            content: Text(state.errorMessage ?? 'Unknown error.'),
            severity: InfoBarSeverity.error,
            isLong: true,
            action: Button(
              onPressed: controller.load,
              child: const Text('Try again'),
            ),
          ),
        );
      case IssueLoadStatus.ready:
        break;
    }

    final rows = state.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoBar(
              title: Text(state.errorMessage!),
              severity: InfoBarSeverity.warning,
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= kWideTableMinWidth;
              return Column(
                children: [
                  if (wide)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: _HeaderRow(),
                    ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: Text(
                              state.items.isEmpty
                                  ? 'No issues found.'
                                  : 'No loaded issue matches the search.'
                                      '${state.hasMore ? ' Load more to search further.' : ''}',
                            ),
                          )
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, i) =>
                                _IssueRow(issue: rows[i], wide: wide),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: state.loadingMore
                ? const ProgressRing()
                : Button(
                    onPressed: controller.loadMore,
                    child: const Text('Load more'),
                  ),
          ),
      ],
    );
  }
}

const _columns = <(String, int)>[
  ('Code', 2),
  ('Title', 4),
  ('Type', 2),
  ('Priority', 1),
  ('Status', 2),
  ('Assigned to', 2),
  ('Reported (Malaysia)', 2),
  ('', 1),
];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final (title, flex) in _columns)
            TableCell2(flex: flex, child: HeaderText(title)),
        ],
      );
}

class _IssueRow extends ConsumerWidget {
  const _IssueRow({required this.issue, required this.wide});

  final IssueItem issue;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = {
      for (final e in ref.watch(activeEmployeesProvider).value ?? const <Employee>[])
        e.employeeId: e.name,
    };
    final assignee = issue.assignedEmployeeId.isEmpty
        ? 'Not assigned'
        : (names[issue.assignedEmployeeId] ?? issue.assignedEmployeeId);
    final chip = StatusChip(label: issue.status.label, color: _statusColor(issue.status));
    final open = Button(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => IssueDetailDialog(initial: issue),
      ),
      child: const Text('Open'),
    );
    final reported = formatMalaysiaTime(issue.reportedAtUtc);

    if (!wide) {
      return RowCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    issue.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FluentTheme.of(context).typography.bodyStrong,
                  ),
                ),
                const SizedBox(width: 8),
                chip,
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${issue.issueCode}  ·  ${issue.issueType}  ·  '
              '${issue.priority.label}  ·  $assignee',
            ),
            const SizedBox(height: 4),
            Text('Reported $reported'),
            const SizedBox(height: 10),
            open,
          ],
        ),
      );
    }

    Widget text(int i, String v, {Color? color}) => TableCell2(
          flex: _columns[i].$2,
          child: Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: color == null ? null : TextStyle(color: color),
          ),
        );
    final urgent = issue.priority == TaskPriority.critical ||
        issue.priority == TaskPriority.high;
    return RowCard(
      child: Row(
        children: [
          text(0, issue.issueCode),
          text(1, issue.title),
          text(2, issue.issueType),
          text(
            3,
            issue.priority.label,
            color: urgent && !issue.status.isFinal ? StatusColors.danger : null,
          ),
          TableCell2(
            flex: _columns[4].$2,
            child: Align(alignment: Alignment.centerLeft, child: chip),
          ),
          text(5, assignee),
          text(6, reported),
          TableCell2(flex: _columns[7].$2, child: open),
        ],
      ),
    );
  }

  Color _statusColor(IssueStatus s) => switch (s) {
        IssueStatus.open => StatusColors.danger,
        IssueStatus.assigned => StatusColors.info,
        IssueStatus.investigating => StatusColors.active,
        IssueStatus.waiting => StatusColors.warning,
        IssueStatus.resolved => StatusColors.success,
        IssueStatus.closed => StatusColors.neutral,
      };
}
