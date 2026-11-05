import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/rule_violation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/malaysia_time.dart';
import '../../models/task_item.dart';
import '../../models/time_log.dart';
import '../../shared/layouts/page_frame.dart';
import '../../shared/widgets/elapsed_text.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/table_parts.dart';
import '../task_management/task_action_dialog.dart';
import 'time_tracker_controller.dart';
import 'time_tracker_state.dart';

/// Start, pause, resume and end work on my In Progress tasks.
/// The running timer is read from SharePoint, so it survives a restart.
class TimeTrackerPage extends ConsumerWidget {
  const TimeTrackerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timeTrackerControllerProvider);
    final controller = ref.read(timeTrackerControllerProvider.notifier);

    return PageFrame(
      title: 'Time Tracker',
      child: switch (state.status) {
        TimerLoadStatus.loading when state.active == null && state.logs.isEmpty =>
          const Center(child: ProgressRing()),
        TimerLoadStatus.failed => Align(
            alignment: Alignment.topLeft,
            child: InfoBar(
              title: const Text('Could not load the time tracker'),
              content: Text(state.errorMessage ?? 'Unknown error.'),
              severity: InfoBarSeverity.error,
              isLong: true,
              action: Button(
                onPressed: controller.load,
                child: const Text('Try again'),
              ),
            ),
          ),
        _ => _Content(state: state),
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.state});

  final TimeTrackerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    return ListView(
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoBar(
              title: Text(state.errorMessage!),
              severity: InfoBarSeverity.error,
              isLong: true,
            ),
          ),
        _ActiveCard(state: state),
        const SizedBox(height: 20),
        Text('My tasks in progress', style: theme.typography.subtitle),
        const SizedBox(height: 8),
        if (state.myTasks.isEmpty)
          const Text(
            'No tasks in progress. Accept a task and choose Start work on the '
            'Tasks page first.',
          )
        else
          for (final task in state.myTasks) _TaskRow(task: task, state: state),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('Today', style: theme.typography.subtitle),
            const Spacer(),
            Text('Total finished: ${formatMinutes(state.totalMinutes)}'),
          ],
        ),
        const SizedBox(height: 8),
        if (state.logs.isEmpty)
          const Text('Nothing finished yet today.')
        else
          for (final log in state.logs) _LogRow(log: log),
      ],
    );
  }
}

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.state});

  final TimeTrackerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = state.active;
    final theme = FluentTheme.of(context);

    if (active == null) {
      return RowCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const StatusChip(label: 'No timer running', color: StatusColors.neutral),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                state.pausedTaskCode == null
                    ? 'Choose a task below and press Start.'
                    : 'Paused on ${state.pausedTaskCode}. Press Resume below.',
              ),
            ),
          ],
        ),
      );
    }

    final title = state.myTasks
        .where((t) => t.taskCode == active.taskCode)
        .map((t) => t.title)
        .firstOrNull;
    final controller = ref.read(timeTrackerControllerProvider.notifier);

    return RowCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusChip(label: 'Running', color: StatusColors.active),
                const SizedBox(height: 8),
                Text(
                  title == null ? active.taskCode : '${active.taskCode}: $title',
                  style: theme.typography.bodyStrong,
                ),
                const SizedBox(height: 4),
                Text('Started ${formatMalaysiaTime(active.startUtc)} (Malaysia)'),
              ],
            ),
          ),
          ElapsedText(
            startUtc: active.startUtc,
            style: theme.typography.titleLarge,
          ),
          const SizedBox(width: 24),
          Button(
            onPressed: state.busy ? null : controller.pause,
            child: const Text('Pause'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: state.busy ? null : () => _end(context, ref, active),
            child: const Text('End job'),
          ),
        ],
      ),
    );
  }

  Future<void> _end(BuildContext context, WidgetRef ref, TimeLog active) =>
      showDialog<bool>(
        context: context,
        builder: (_) => TaskActionDialog(
          title: 'End job',
          summary: '${active.taskCode}. The timer stops now. The task stays In '
              'Progress. Submit it for review on the Tasks page when the work '
              'is finished.',
          textLabel: 'What did you do in this session?',
          confirmLabel: 'End job',
          onConfirm: (input) async {
            final message = await ref
                .read(timeTrackerControllerProvider.notifier)
                .end(input.text);
            if (message != null) throw _Shown(message);
          },
        ),
      );
}

/// Carries a message from the controller to the dialog.
class _Shown implements RuleViolation {
  _Shown(this.message);

  @override
  final String message;
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.state});

  final TaskItem task;
  final TimeTrackerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = state.active?.taskCode == task.taskCode;
    final isPaused = state.pausedTaskCode == task.taskCode;
    final blocked = state.active != null || state.busy;
    return RowCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${task.taskCode}  ·  ${task.progress}% done',
                  style: TextStyle(
                    color: FluentTheme.of(context).resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isPaused) ...[
            const StatusChip(label: 'Paused', color: StatusColors.warning),
            const SizedBox(width: 12),
          ],
          if (isRunning)
            const StatusChip(label: 'Running', color: StatusColors.active)
          else
            FilledButton(
              onPressed: blocked
                  ? null
                  : () => ref.read(timeTrackerControllerProvider.notifier).start(task),
              child: Text(isPaused ? 'Resume' : 'Start'),
            ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});

  final TimeLog log;

  @override
  Widget build(BuildContext context) {
    final end = log.endUtc;
    final start = toMalaysiaTime(log.startUtc);
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return RowCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(log.taskCode)),
          SizedBox(
            width: 130,
            child: Text('${hm(start)} - ${end == null ? '' : hm(toMalaysiaTime(end))}'),
          ),
          SizedBox(width: 90, child: Text(formatMinutes(log.durationMinutes ?? 0))),
          Expanded(
            child: Text(
              log.workResult,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
