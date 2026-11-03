import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/graph_client.dart';
import '../../models/task_draft.dart';
import '../../models/task_enums.dart';
import '../../models/task_item.dart';
import '../../services/task_service.dart';
import '../../services/task_validator.dart';
import '../../shared/widgets/malaysia_date_time_field.dart';
import '../../state/providers.dart';
import 'task_list_controller.dart';

/// Create or edit one task. Pops `true` when the task was saved.
/// Only form state lives here. The rules are in [TaskService].
class TaskFormDialog extends ConsumerStatefulWidget {
  const TaskFormDialog({super.key, this.existing});

  /// Null means create a new task.
  final TaskItem? existing;

  @override
  ConsumerState<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _estimate;
  late final TextEditingController _project;
  String? _type;
  String? _assignee;
  String _priority = TaskPriority.normal.label;
  DateTime? _plannedStart;
  DateTime? _expected;
  bool _docRequired = true;

  Map<TaskFormField, String> _errors = const {};
  String? _message;
  bool _saving = false;

  bool get _isCreate => widget.existing == null;

  /// The original estimate is fixed once the task is accepted.
  bool get _estimateLocked =>
      !_isCreate && widget.existing!.status != TaskStatus.newTask;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _title = TextEditingController(text: t?.title ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _estimate = TextEditingController(
      text: t == null ? '' : t.estimatedHours.toString(),
    );
    _project = TextEditingController(text: t?.projectCode ?? '');
    _type = taskTypes.contains(t?.taskType) ? t?.taskType : null;
    _assignee = t?.assignedEmployeeId;
    _priority = t?.priority.label ?? TaskPriority.normal.label;
    _plannedStart = t?.plannedStart;
    _expected = t?.expectedCompletion;
    _docRequired = t?.documentationRequired ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _estimate.dispose();
    _project.dispose();
    super.dispose();
  }

  TaskDraft _draft() => TaskDraft(
        title: _title.text,
        description: _description.text,
        taskType: _type ?? '',
        assignedEmployeeId: _assignee ?? '',
        priority: _priority,
        projectCode: _project.text,
        estimatedHours: double.tryParse(_estimate.text.trim()),
        plannedStart: _plannedStart,
        expectedCompletion: _expected,
        documentationRequired: _docRequired,
      );

  Future<void> _save() async {
    final draft = _draft();
    final errors = TaskValidator.validate(
      draft,
      nowUtc: _isCreate ? DateTime.now().toUtc() : null,
    );
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _message = 'Please fix the highlighted fields.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errors = const {};
      _message = null;
    });
    final controller = ref.read(taskListControllerProvider.notifier);
    try {
      if (_isCreate) {
        await controller.create(draft);
      } else {
        await controller.edit(widget.existing!, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } on TaskRuleException catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(activeEmployeesProvider);

    return ContentDialog(
      title: Text(_isCreate ? 'New task' : 'Edit ${widget.existing!.taskCode}'),
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
              TaskFormField.title,
            ),
            _field(
              'Description',
              TextBox(
                controller: _description,
                enabled: !_saving,
                minLines: 3,
                maxLines: 6,
              ),
              TaskFormField.description,
            ),
            _field(
              'Task type',
              ComboBox<String>(
                value: _type,
                placeholder: const Text('Choose'),
                items: [
                  for (final t in taskTypes)
                    ComboBoxItem<String>(value: t, child: Text(t)),
                ],
                onChanged: _saving ? null : (v) => setState(() => _type = v),
              ),
              TaskFormField.taskType,
            ),
            _field(
              'Assigned to',
              employees.when(
                loading: () => const ProgressRing(),
                error: (e, _) => const Text('Could not load employees.'),
                data: (list) => ComboBox<String>(
                  value: list.any((e) => e.employeeId == _assignee)
                      ? _assignee
                      : null,
                  placeholder: Text(
                    _assignee == null || _assignee!.isEmpty
                        ? 'Choose'
                        : _assignee!,
                  ),
                  items: [
                    for (final e in list)
                      ComboBoxItem<String>(
                        value: e.employeeId,
                        child: Text('${e.name} (${e.employeeId})'),
                      ),
                  ],
                  onChanged:
                      _saving ? null : (v) => setState(() => _assignee = v),
                ),
              ),
              TaskFormField.assignee,
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
              TaskFormField.priority,
            ),
            _field(
              'Project code (optional)',
              TextBox(controller: _project, enabled: !_saving),
              TaskFormField.projectCode,
            ),
            _field(
              _estimateLocked
                  ? 'Estimated hours (locked after acceptance)'
                  : 'Estimated hours',
              TextBox(
                controller: _estimate,
                enabled: !_saving && !_estimateLocked,
              ),
              TaskFormField.estimate,
            ),
            _field(
              'Planned start, Malaysia time (optional)',
              MalaysiaDateTimeField(
                value: _plannedStart,
                enabled: !_saving,
                defaultHour: 9,
                onChanged: (v) => setState(() => _plannedStart = v),
              ),
              TaskFormField.plannedStart,
            ),
            _field(
              'Expected completion, Malaysia time',
              MalaysiaDateTimeField(
                value: _expected,
                enabled: !_saving,
                onChanged: (v) => setState(() => _expected = v),
              ),
              TaskFormField.expectedCompletion,
            ),
            Checkbox(
              checked: _docRequired,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _docRequired = v ?? true),
              content: const Text('Documentation required'),
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
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(String label, Widget child, [TaskFormField? field]) {
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
                child: Text(error, style: const TextStyle(color: StatusColors.danger)),
              ),
          ],
        ),
      ),
    );
  }
}
