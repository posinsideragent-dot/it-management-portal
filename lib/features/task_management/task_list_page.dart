import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/malaysia_time.dart';
import '../../models/employee.dart';
import '../../models/task_enums.dart';
import '../../models/task_item.dart';
import '../../services/task_access.dart';
import '../../services/task_capabilities.dart';
import '../../services/task_workflow.dart';
import '../../shared/layouts/page_frame.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/table_parts.dart';
import '../../state/providers.dart';
import 'task_detail_dialog.dart';
import 'task_form_dialog.dart';
import 'task_list_controller.dart';
import 'task_list_state.dart';
import 'task_progress_dialog.dart';
import 'task_status_dialog.dart';

/// Tasks table with search, filters, create, edit, status changes and
/// progress. Team Leads, Management and Admin create and edit. The assignee
/// works on their own tasks. Everyone can read.
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskListControllerProvider);
    final user = ref.watch(currentUserProvider);
    final isLead = user != null && TaskAccess.forUser(user).isLead;

    return PageFrame(
      title: 'Tasks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Toolbar(state: state, isLead: isLead),
          const SizedBox(height: 12),
          Expanded(child: _Body(state: state)),
        ],
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.state, required this.isLead});

  final TaskListState state;
  final bool isLead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(taskListControllerProvider.notifier);
    return Wrap(
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
          value: state.statusFilter?.label ?? _allStatuses,
          items: [
            const ComboBoxItem<String>(
              value: _allStatuses,
              child: Text('All statuses'),
            ),
            for (final s in TaskStatus.values)
              ComboBoxItem<String>(value: s.label, child: Text(s.label)),
          ],
          onChanged: (v) => controller.setStatusFilter(
            v == null || v == _allStatuses ? null : TaskStatus.tryParse(v),
          ),
        ),
        ToggleSwitch(
          checked: state.mineOnly,
          onChanged: controller.setMineOnly,
          content: const Text('My tasks'),
        ),
        Button(onPressed: controller.load, child: const Text('Refresh')),
        if (isLead)
          FilledButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => const TaskFormDialog(),
            ),
            child: const Text('New task'),
          ),
      ],
    );
  }

  static const _allStatuses = '__all__';
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final TaskListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(taskListControllerProvider.notifier);

    switch (state.status) {
      case TaskLoadStatus.loading:
        return const Center(child: ProgressRing());
      case TaskLoadStatus.failed:
        return Align(
          alignment: Alignment.topLeft,
          child: InfoBar(
            title: const Text('Could not load tasks'),
            content: Text(state.errorMessage ?? 'Unknown error.'),
            severity: InfoBarSeverity.error,
            isLong: true,
            action: Button(
              onPressed: controller.load,
              child: const Text('Try again'),
            ),
          ),
        );
      case TaskLoadStatus.ready:
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
                                  ? 'No tasks found.'
                                  : 'No loaded task matches the search.'
                                      '${state.hasMore ? ' Load more to search further.' : ''}',
                            ),
                          )
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, i) =>
                                _TaskRow(task: rows[i], wide: wide),
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

/// Column titles and widths (flex), shared by the header and the rows.
const _columns = <(String, int)>[
  ('Code', 2),
  ('Title', 3),
  ('Assigned to', 2),
  ('Priority', 1),
  ('Status', 2),
  ('Est. hours', 1),
  ('Due (Malaysia)', 2),
  ('Progress', 1),
  ('Actions', 4),
];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (title, flex) in _columns)
          TableCell2(flex: flex, child: HeaderText(title)),
      ],
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.wide});

  final TaskItem task;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final names = _names(ref.watch(activeEmployeesProvider).value);
    final actors =
        user == null ? <TaskActor>{} : TaskAccess.actorsFor(user, task);
    final assignee = names[task.assignedEmployeeId] ?? task.assignedEmployeeId;
    final overdue = !task.status.isFinal &&
        task.expectedCompletion.isBefore(DateTime.now().toUtc());
    final due = formatMalaysiaTime(task.expectedCompletion);
    final dueColor = overdue ? StatusColors.danger : null;
    final caps = user == null ? null : TaskCapabilities.of(user, task);
    final actions = _actions(context, actors, caps);
    final hours = _hoursLabel();

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
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FluentTheme.of(context).typography.bodyStrong,
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(),
              ],
            ),
            const SizedBox(height: 4),
            Text('${task.taskCode}  \u00b7  $assignee  \u00b7  ${task.priority.label}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Due $due', style: TextStyle(color: dueColor)),
                const SizedBox(width: 16),
                Text(hours),
                const SizedBox(width: 16),
                Expanded(child: _progress()),
              ],
            ),
            const SizedBox(height: 10),
            actions,
          ],
        ),
      );
    }

    Widget text(int index, String value, {Color? color}) => TableCell2(
          flex: _columns[index].$2,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: color == null ? null : TextStyle(color: color),
          ),
        );

    return RowCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          text(0, task.taskCode),
          text(1, task.title),
          text(2, assignee),
          text(3, task.priority.label),
          TableCell2(
            flex: _columns[4].$2,
            child: Align(alignment: Alignment.centerLeft, child: _statusChip()),
          ),
          text(5, hours),
          text(6, due, color: dueColor),
          TableCell2(flex: _columns[7].$2, child: _progress()),
          TableCell2(
            flex: _columns[8].$2,
            child: actions,
          ),
        ],
      ),
    );
  }

  /// Details, edit, status moves and progress.
  Widget _actions(
    BuildContext context,
    Set<TaskActor> actors,
    TaskCapabilities? caps,
  ) {
    final moves = TaskWorkflow.movesFor(task.status, actors);
    final canEdit = actors.contains(TaskActor.lead) && !task.status.isFinal;
    final canProgress =
        actors.contains(TaskActor.assignee) &&
        task.status == TaskStatus.inProgress;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Button(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => TaskDetailDialog(initial: task),
          ),
          child: Text(caps?.hasAny == true ? 'Details \u2022' : 'Details'),
        ),
        if (canEdit)
          Button(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => TaskFormDialog(existing: task),
            ),
            child: const Text('Edit'),
          ),
        for (final move in moves)
          Button(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => TaskStatusDialog(task: task, move: move),
            ),
            child: Text(move.label),
          ),
        if (canProgress)
          Button(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => TaskProgressDialog(task: task),
            ),
            child: const Text('Progress'),
          ),
      ],
    );
  }

  /// Hours in force. A star means a revision waits for approval.
  String _hoursLabel() =>
      '${_hours(task.effectiveEstimateHours)}${task.hasPendingRevision ? ' *' : ''}';

  Widget _progress() => Row(
        children: [
          Expanded(child: ProgressBar(value: task.progress.toDouble())),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('${task.progress}%', maxLines: 1),
          ),
        ],
      );

  /// The status chip. Hover shows the last reason (hold, cancel, return).
  Widget _statusChip() {
    final chip = StatusChip(
      label: task.status.label,
      color: _statusColor(task.status),
    );
    if (task.blockerRemarks.isEmpty) return chip;
    return Tooltip(message: task.blockerRemarks, child: chip);
  }

  Map<String, String> _names(List<Employee>? employees) => {
        for (final e in employees ?? const <Employee>[]) e.employeeId: e.name,
      };

  String _hours(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  Color _statusColor(TaskStatus status) => switch (status) {
        TaskStatus.completed => StatusColors.success,
        TaskStatus.cancelled => StatusColors.neutral,
        TaskStatus.onHold => StatusColors.warning,
        TaskStatus.pendingReview => StatusColors.info,
        TaskStatus.inProgress => StatusColors.active,
        _ => StatusColors.neutral,
      };
}
