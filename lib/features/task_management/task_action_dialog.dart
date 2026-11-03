import 'package:fluent_ui/fluent_ui.dart';

import '../../core/errors/rule_violation.dart';
import '../../data/api/graph_client.dart';

/// What the person typed into [TaskActionDialog].
class TaskActionInput {
  const TaskActionInput({this.hours, this.text = ''});

  /// Null when the dialog has no hours box or the box is not a number.
  final double? hours;
  final String text;
}

/// One small dialog used for actions that need a reason or a number
/// (task revisions, documentation, ending a timer).
/// It shows an optional hours box and an optional text box, runs [onConfirm],
/// and shows any rule or SharePoint error inside the dialog.
/// Pops `true` when the action was saved.
class TaskActionDialog extends StatefulWidget {
  const TaskActionDialog({
    super.key,
    required this.title,
    required this.summary,
    required this.confirmLabel,
    required this.onConfirm,
    this.textLabel,
    this.hoursLabel,
  });

  final String title;
  final String summary;
  final String confirmLabel;
  final String? textLabel;
  final String? hoursLabel;
  final Future<void> Function(TaskActionInput input) onConfirm;

  @override
  State<TaskActionDialog> createState() => _TaskActionDialogState();
}

class _TaskActionDialogState extends State<TaskActionDialog> {
  final _hours = TextEditingController();
  final _text = TextEditingController();
  String? _message;
  bool _saving = false;

  @override
  void dispose() {
    _hours.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.onConfirm(
        TaskActionInput(
          hours: double.tryParse(_hours.text.trim()),
          text: _text.text,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on RuleViolation catch (e) {
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
      title: Text(widget.title),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.summary),
          const SizedBox(height: 12),
          if (_message != null) ...[
            InfoBar(title: Text(_message!), severity: InfoBarSeverity.error),
            const SizedBox(height: 12),
          ],
          if (widget.hoursLabel != null) ...[
            InfoLabel(
              label: widget.hoursLabel!,
              child: TextBox(controller: _hours, enabled: !_saving),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.textLabel != null)
            InfoLabel(
              label: widget.textLabel!,
              child: TextBox(
                controller: _text,
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
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
