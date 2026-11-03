import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/malaysia_time.dart';
import '../../models/task_item.dart';
import '../../services/task_capabilities.dart';
import '../../state/providers.dart';
import 'task_action_dialog.dart';
import 'task_list_controller.dart';

/// Everything about one task, with the estimate and documentation actions.
/// It follows the list, so it shows the saved values after an action.
class TaskDetailDialog extends ConsumerWidget {
  const TaskDetailDialog({super.key, required this.initial});

  final TaskItem initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(taskListControllerProvider).items;
    final task = items.firstWhere(
      (t) => t.itemId == initial.itemId,
      orElse: () => initial,
    );
    final user = ref.watch(currentUserProvider);
    final caps = user == null ? null : TaskCapabilities.of(user, task);
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 680),
      title: Text('${task.taskCode}: ${task.title}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _section(theme, 'Task'),
            _row('Status', task.status.label),
            _row('Type', task.taskType),
            _row('Priority', task.priority.label),
            _row('Assigned to', task.assignedEmployeeId),
            if (task.projectCode.isNotEmpty) _row('Project', task.projectCode),
            _row('Progress', '${task.progress}%'),
            _row('Due (Malaysia)', formatMalaysiaTime(task.expectedCompletion)),
            _row('Description', task.description),
            if (task.completionRemarks.isNotEmpty)
              _row('Completion remarks', task.completionRemarks),
            if (task.blockerRemarks.isNotEmpty)
              _row('Last reason', task.blockerRemarks),
            const SizedBox(height: 12),
            _section(theme, 'Estimate'),
            _row('Original', '${_h(task.estimatedHours)} h'),
            if (task.revisedEstimatedHours != null)
              _row(
                'Revised (approved)',
                '${_h(task.revisedEstimatedHours!)} h'
                '${task.estimateApprovedBy.isEmpty ? '' : ' by ${task.estimateApprovedBy}'}',
              ),
            if (task.hasPendingRevision)
              _row(
                'Waiting for approval',
                '${_h(task.proposedEstimatedHours!)} h',
              ),
            if (task.estimateRevisionReason.isNotEmpty)
              _row('Revision reason', task.estimateRevisionReason),
            if (caps != null && (caps.canRequestRevision || caps.canDecideRevision))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (caps.canRequestRevision)
                      Button(
                        onPressed: () => _requestRevision(context, ref, task),
                        child: const Text('Request revision'),
                      ),
                    if (caps.canDecideRevision) ...[
                      FilledButton(
                        onPressed: () => _approveRevision(context, ref, task),
                        child: const Text('Approve revision'),
                      ),
                      Button(
                        onPressed: () => _rejectRevision(context, ref, task),
                        child: const Text('Refuse revision'),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _section(theme, 'Documentation'),
            _row('Required', task.documentationRequired ? 'Yes' : 'No'),
            _row('Status', task.documentationStatus.label),
            if (task.documentationRemarks.isNotEmpty)
              _row('Last note', task.documentationRemarks),
            if (caps != null &&
                (caps.canSubmitDocumentation ||
                    caps.canReviewDocumentation ||
                    caps.canWaiveDocumentation))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (caps.canSubmitDocumentation)
                      FilledButton(
                        onPressed: () => _submitDocs(context, ref, task),
                        child: const Text('Submit documentation'),
                      ),
                    if (caps.canReviewDocumentation) ...[
                      FilledButton(
                        onPressed: () => _reviewDocs(context, ref, task, true),
                        child: const Text('Accept documentation'),
                      ),
                      Button(
                        onPressed: () => _reviewDocs(context, ref, task, false),
                        child: const Text('Send back'),
                      ),
                    ],
                    if (caps.canWaiveDocumentation)
                      Button(
                        onPressed: () => _waiveDocs(context, ref, task),
                        child: const Text('Waive'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  // --- actions ---

  Future<void> _requestRevision(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
  ) =>
      _run(
        context,
        TaskActionDialog(
          title: 'Request estimate revision',
          summary: '${task.taskCode}. Current estimate '
              '${_h(task.effectiveEstimateHours)} h. A Team Lead must approve '
              'the new estimate. The original estimate stays on record.',
          hoursLabel: 'New estimate (hours)',
          textLabel: 'Reason',
          confirmLabel: 'Send request',
          onConfirm: (i) => ref
              .read(taskListControllerProvider.notifier)
              .requestRevision(task, hours: i.hours, reason: i.text),
        ),
      );

  Future<void> _approveRevision(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
  ) =>
      _run(
        context,
        TaskActionDialog(
          title: 'Approve revision',
          summary: '${task.taskCode}: ${_h(task.effectiveEstimateHours)} h '
              'becomes ${_h(task.proposedEstimatedHours ?? 0)} h. '
              'Reason given: ${task.estimateRevisionReason}',
          confirmLabel: 'Approve',
          onConfirm: (_) => ref
              .read(taskListControllerProvider.notifier)
              .approveRevision(task),
        ),
      );

  Future<void> _rejectRevision(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
  ) =>
      _run(
        context,
        TaskActionDialog(
          title: 'Refuse revision',
          summary: '${task.taskCode}: the estimate stays at '
              '${_h(task.effectiveEstimateHours)} h.',
          textLabel: 'Reason for refusing',
          confirmLabel: 'Refuse',
          onConfirm: (i) => ref
              .read(taskListControllerProvider.notifier)
              .rejectRevision(task, i.text),
        ),
      );

  Future<void> _submitDocs(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
  ) =>
      _run(
        context,
        TaskActionDialog(
          title: 'Submit documentation',
          summary: '${task.taskCode}: say where the documentation is.',
          textLabel: 'Where is it? (link, folder or note)',
          confirmLabel: 'Submit',
          onConfirm: (i) => ref
              .read(taskListControllerProvider.notifier)
              .submitDocumentation(task, i.text),
        ),
      );

  Future<void> _reviewDocs(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
    bool accept,
  ) =>
      _run(
        context,
        TaskActionDialog(
          title: accept ? 'Accept documentation' : 'Send documentation back',
          summary: '${task.taskCode}. ${task.documentationRemarks}',
          textLabel: accept ? 'Remarks (optional)' : 'Reason for sending back',
          confirmLabel: accept ? 'Accept' : 'Send back',
          onConfirm: (i) => ref
              .read(taskListControllerProvider.notifier)
              .reviewDocumentation(task, accept: accept, remarks: i.text),
        ),
      );

  Future<void> _waiveDocs(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
  ) =>
      _run(
        context,
        TaskActionDialog(
          title: 'Waive documentation',
          summary: '${task.taskCode}: the task can be approved without '
              'documentation. The reason is kept on record.',
          textLabel: 'Reason for waiving',
          confirmLabel: 'Waive',
          onConfirm: (i) => ref
              .read(taskListControllerProvider.notifier)
              .waiveDocumentation(task, i.text),
        ),
      );

  Future<void> _run(BuildContext context, Widget dialog) =>
      showDialog<bool>(context: context, builder: (_) => dialog);

  // --- layout helpers ---

  Widget _section(FluentThemeData theme, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title, style: theme.typography.bodyStrong),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: Text(label)),
            Expanded(child: SelectableText(value.isEmpty ? '-' : value)),
          ],
        ),
      );

  String _h(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';
}
