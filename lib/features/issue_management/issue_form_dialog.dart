import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/graph_client.dart';
import '../../models/issue.dart';
import '../../models/task_enums.dart';
import '../../services/issue_service.dart';
import 'issue_list_controller.dart';

/// Report or edit one issue. Pops `true` when it was saved.
/// Only form state lives here. The rules are in [IssueService].
class IssueFormDialog extends ConsumerStatefulWidget {
  const IssueFormDialog({super.key, this.existing});

  /// Null means report a new issue.
  final IssueItem? existing;

  @override
  ConsumerState<IssueFormDialog> createState() => _IssueFormDialogState();
}

class _IssueFormDialogState extends ConsumerState<IssueFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _task;
  late final TextEditingController _project;
  String? _type;
  String _priority = TaskPriority.normal.label;

  Map<IssueFormField, String> _errors = const {};
  String? _message;
  bool _saving = false;

  bool get _isCreate => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final i = widget.existing;
    _title = TextEditingController(text: i?.title ?? '');
    _description = TextEditingController(text: i?.description ?? '');
    _task = TextEditingController(text: i?.relatedTaskCode ?? '');
    _project = TextEditingController(text: i?.projectCode ?? '');
    _type = issueTypes.contains(i?.issueType) ? i?.issueType : null;
    _priority = i?.priority.label ?? TaskPriority.normal.label;
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _task, _project]) {
      c.dispose();
    }
    super.dispose();
  }

  IssueDraft _draft() => IssueDraft(
        title: _title.text,
        description: _description.text,
        issueType: _type ?? '',
        priority: _priority,
        relatedTaskCode: _task.text,
        projectCode: _project.text,
      );

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = const {};
      _message = null;
    });
    final controller = ref.read(issueListControllerProvider.notifier);
    try {
      if (_isCreate) {
        await controller.create(_draft());
      } else {
        await controller.edit(widget.existing!, _draft());
      }
      if (mounted) Navigator.pop(context, true);
    } on IssueRuleException catch (e) {
      if (mounted) {
        setState(() {
          _errors = e.fieldErrors;
          _message = e.message;
        });
      }
    } on GraphException catch (e) {
      if (mounted) setState(() => _message = e.userMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, Widget child, [IssueFormField? field]) {
    final error = field == null ? null : _errors[field];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoLabel(
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child,
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: const TextStyle(color: StatusColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(_isCreate ? 'Report an issue' : 'Edit ${widget.existing!.issueCode}'),
      constraints: const BoxConstraints(maxWidth: 560),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_message != null) ...[
              InfoBar(title: Text(_message!), severity: InfoBarSeverity.error),
              const SizedBox(height: 12),
            ],
            _field(
              'Title',
              TextBox(controller: _title, enabled: !_saving),
              IssueFormField.title,
            ),
            _field(
              'Description',
              TextBox(
                controller: _description,
                enabled: !_saving,
                minLines: 3,
                maxLines: 6,
              ),
              IssueFormField.description,
            ),
            _field(
              'Issue type',
              ComboBox<String>(
                value: _type,
                placeholder: const Text('Choose'),
                items: [
                  for (final t in issueTypes)
                    ComboBoxItem<String>(value: t, child: Text(t)),
                ],
                onChanged: _saving ? null : (v) => setState(() => _type = v),
              ),
              IssueFormField.issueType,
            ),
            _field(
              'Priority',
              ComboBox<String>(
                value: _priority,
                items: [
                  for (final p in TaskPriority.labels)
                    ComboBoxItem<String>(value: p, child: Text(p)),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _priority = v ?? _priority),
              ),
              IssueFormField.priority,
            ),
            _field(
              'Related task code (optional)',
              TextBox(
                controller: _task,
                enabled: !_saving,
                placeholder: 'TASK-2026-00001',
              ),
              IssueFormField.relatedTask,
            ),
            _field(
              'Project code (optional)',
              TextBox(controller: _project, enabled: !_saving),
              IssueFormField.project,
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_isCreate ? 'Report issue' : 'Save'),
        ),
      ],
    );
  }
}
