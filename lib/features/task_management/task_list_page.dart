import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/malaysia_time.dart';
import '../../models/employee.dart';
import '../../models/task_enums.dart';
import '../../models/task_item.dart';
import '../../services/task_access.dart';
import '../../services/task_workflow.dart';
import '../../shared/layouts/page_frame.dart';
import '../../state/providers.dart';
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
        const _HeaderRow(),
        const Divider(),
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
                  itemBuilder: (context, i) => _TaskRow(task: rows[i]),
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
    final style = FluentTheme.of(context).typography.bodyStrong;
    return Row(
      children: [
        for (final (title, flex) in _columns)
          Expanded(flex: flex, child: Text(title, style: style)),
      ],
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final names = _names(ref.watch(activeEmployeesProvider).valueOrNull);
    final actors =
        user == null ? <TaskActor>{} : TaskAccess.actorsFor(user, task);
    final moves = TaskWorkflow.movesFor(task.status, actors);
    final canEdit = actors.contains(TaskActor.lead) && !task.status.isFinal;
    final canProgress =
        actors.contains(TaskActor.assignee) &&
        task.status == TaskStatus.inProgress;
    final overdue = !task.status.isFinal &&
        task.expectedCompletion.isBefore(DateTime.now().toUtc());

    Widget cell(int index, Widget child) =>
        Expanded(flex: _columns[index].$2, child: child);
    Widget text(int index, String value, {Color? color}) => cell(
          index,
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: color == null ? null : TextStyle(color: color),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text(0, task.taskCode),
          text(1, task.title),
          text(2, names[task.assignedEmployeeId] ?? task.assignedEmployeeId),
          text(3, task.priority.label),
          cell(
            4,
            Tooltip(
              message: task.blockerRemarks.isEmpty ? '' : task.blockerRemarks,
              child: Text(
                task.status.label,
                style: TextStyle(color: _statusColor(task.status)),
              ),
            ),
          ),
          text(5, _hours(task.estimatedHours)),
          text(
            6,
            formatMalaysiaTime(task.expectedCompletion),
            color: overdue ? Colors.red : null,
          ),
          text(7, '${task.progress}%'),
          cell(
            8,
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
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
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _names(List<Employee>? employees) => {
        for (final e in employees ?? const <Employee>[]) e.employeeId: e.name,
      };

  String _hours(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  Color? _statusColor(TaskStatus status) => switch (status) {
        TaskStatus.completed => Colors.green,
        TaskStatus.cancelled => Colors.grey,
        TaskStatus.onHold => Colors.orange,
        TaskStatus.pendingReview => Colors.blue,
        _ => null,
      };
}
