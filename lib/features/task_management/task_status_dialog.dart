import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/graph_client.dart';
import '../../models/task_item.dart';
import '../../services/task_service.dart';
import '../../services/task_workflow.dart';
import 'task_list_controller.dart';

/// Confirms a status change and asks for the reason when the rule needs one.
/// Pops `true` when the change was saved.
class TaskStatusDialog extends ConsumerStatefulWidget {
  const TaskStatusDialog({super.key, required this.task, required this.move});

  final TaskItem task;
  final TaskMove move;

  @override
  ConsumerState<TaskStatusDialog> createState() => _TaskStatusDialogState();
}

class _TaskStatusDialogState extends ConsumerState<TaskStatusDialog> {
  final _remarks = TextEditingController();
  String? _message;
  bool _saving = false;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref.read(taskListControllerProvider.notifier).changeStatus(
            widget.task,
            widget.move.to,
            remarks: _remarks.text,
          );
      if (mounted) Navigator.pop(context, true);
    } on TaskRuleException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } on GraphException catch (e) {
      if (mounted) setState(() => _message = e.userMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final move = widget.move;
    return ContentDialog(
      title: Text(move.label),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.task.taskCode}: ${widget.task.title}\n'
            '${move.from.label} to ${move.to.label}',
          ),
          const SizedBox(height: 12),
          if (_message != null) ...[
            InfoBar(title: Text(_message!), severity: InfoBarSeverity.error),
            const SizedBox(height: 12),
          ],
          if (move.needsRemarks)
            InfoLabel(
              label: move.remarksLabel!,
              child: TextBox(
                controller: _remarks,
                enabled: !_saving,
                minLines: 2,
                maxLines: 5,
              ),
            ),
        ],
      ),
      actions: [
        Button(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _confirm,
          child: Text(move.label),
        ),
      ],
    );
  }
}
