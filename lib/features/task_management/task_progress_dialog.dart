import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/graph_client.dart';
import '../../models/task_item.dart';
import '../../services/task_service.dart';
import 'task_list_controller.dart';

/// The assignee sets progress from 0 to 100. Pops `true` when saved.
class TaskProgressDialog extends ConsumerStatefulWidget {
  const TaskProgressDialog({super.key, required this.task});

  final TaskItem task;

  @override
  ConsumerState<TaskProgressDialog> createState() => _TaskProgressDialogState();
}

class _TaskProgressDialogState extends ConsumerState<TaskProgressDialog> {
  late double _value = widget.task.progress.toDouble();
  String? _message;
  bool _saving = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref
          .read(taskListControllerProvider.notifier)
          .updateProgress(widget.task, _value.round());
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
    return ContentDialog(
      title: const Text('Update progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.task.taskCode}: ${widget.task.title}'),
          const SizedBox(height: 12),
          if (_message != null) ...[
            InfoBar(title: Text(_message!), severity: InfoBarSeverity.error),
            const SizedBox(height: 12),
          ],
          Text('${_value.round()}%'),
          Slider(
            value: _value,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: _saving ? null : (v) => setState(() => _value = v),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
