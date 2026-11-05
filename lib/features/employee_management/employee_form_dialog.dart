import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/graph_client.dart';
import '../../models/app_role.dart';
import '../../models/employee.dart';
import '../../models/employee_draft.dart';
import '../../services/employee_service.dart';
import '../../services/employee_validator.dart';
import 'employee_list_controller.dart';

/// Add or edit one employee. Pops `true` when the row was saved.
/// Only form state lives here. The rules are in [EmployeeService].
class EmployeeFormDialog extends ConsumerStatefulWidget {
  const EmployeeFormDialog({super.key, this.existing});

  /// Null means add a new employee.
  final Employee? existing;

  @override
  ConsumerState<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<EmployeeFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _objectId;
  late final TextEditingController _jobTitle;
  late final TextEditingController _manager;
  String? _department;
  String? _role;
  DateTime? _joinDate;

  Map<EmployeeFormField, String> _errors = const {};
  String? _message;
  bool _saving = false;

  bool get _isCreate => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _objectId = TextEditingController(text: e?.entraObjectId ?? '');
    _jobTitle = TextEditingController(text: e?.jobTitle ?? '');
    _manager = TextEditingController(text: e?.managerEmployeeId ?? '');
    _department =
        employeeDepartments.contains(e?.department) ? e?.department : null;
    _role = AppRole.labels.contains(e?.appRole) ? e?.appRole : null;
    _joinDate = e?.joinDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _objectId.dispose();
    _jobTitle.dispose();
    _manager.dispose();
    super.dispose();
  }

  EmployeeDraft _draft() => EmployeeDraft(
        name: _name.text,
        email: _email.text,
        entraObjectId: _objectId.text,
        department: _department ?? '',
        appRole: _role ?? '',
        jobTitle: _jobTitle.text,
        joinDate: _joinDate,
        managerEmployeeId: _manager.text,
      );

  Future<void> _save() async {
    final draft = _draft();
    final errors = EmployeeValidator.validate(draft, isCreate: _isCreate);
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
    final controller = ref.read(employeeListControllerProvider.notifier);
    try {
      if (_isCreate) {
        await controller.create(draft);
      } else {
        await controller.edit(widget.existing!, draft);
      }
      if (mounted) Navigator.pop(context, true);
    } on EmployeeRuleException catch (e) {
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
    return ContentDialog(
      title: Text(_isCreate ? 'Add employee' : 'Edit employee'),
      constraints: const BoxConstraints(maxWidth: 520),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_message != null) ...[
              InfoBar(
                title: Text(_message!),
                severity: InfoBarSeverity.error,
              ),
              const SizedBox(height: 12),
            ],
            if (!_isCreate)
              _field('Employee ID', Text(widget.existing!.employeeId)),
            _field(
              'Name',
              TextBox(controller: _name, enabled: !_saving),
              EmployeeFormField.name,
            ),
            _field(
              'Email',
              TextBox(controller: _email, enabled: !_saving),
              EmployeeFormField.email,
            ),
            _field(
              'Microsoft Object ID',
              _isCreate
                  ? TextBox(
                      controller: _objectId,
                      enabled: !_saving,
                      placeholder: 'From Entra admin center, Users',
                    )
                  : Text(widget.existing!.entraObjectId),
              EmployeeFormField.entraObjectId,
            ),
            _field(
              'Job title',
              TextBox(controller: _jobTitle, enabled: !_saving),
            ),
            _field(
              'Department',
              ComboBox<String>(
                value: _department,
                placeholder: const Text('Choose'),
                items: [
                  for (final d in employeeDepartments)
                    ComboBoxItem<String>(value: d, child: Text(d)),
                ],
                onChanged:
                    _saving ? null : (v) => setState(() => _department = v),
              ),
              EmployeeFormField.department,
            ),
            _field(
              'Role',
              ComboBox<String>(
                value: _role,
                placeholder: const Text('Choose'),
                items: [
                  for (final r in AppRole.labels)
                    ComboBoxItem<String>(value: r, child: Text(r)),
                ],
                onChanged: _saving ? null : (v) => setState(() => _role = v),
              ),
              EmployeeFormField.appRole,
            ),
            _field(
              'Join date',
              Row(
                children: [
                  DatePicker(
                    selected: _joinDate == null
                        ? null
                        : DateTime(
                            _joinDate!.year,
                            _joinDate!.month,
                            _joinDate!.day,
                          ),
                    onChanged: _saving
                        ? null
                        : (d) => setState(
                              () => _joinDate =
                                  DateTime.utc(d.year, d.month, d.day),
                            ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: _saving || _joinDate == null
                        ? null
                        : () => setState(() => _joinDate = null),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            _field(
              'Manager Employee ID',
              TextBox(
                controller: _manager,
                enabled: !_saving,
                placeholder: 'EMP-0001 (optional)',
              ),
              EmployeeFormField.managerEmployeeId,
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

  Widget _field(String label, Widget child, [EmployeeFormField? field]) {
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
