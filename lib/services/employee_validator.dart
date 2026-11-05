import '../models/app_role.dart';
import '../models/employee_draft.dart';

/// Form fields that can have an error.
enum EmployeeFormField {
  name,
  email,
  entraObjectId,
  department,
  appRole,
  managerEmployeeId,
}

/// Rules for the employee form. The UI uses it for quick feedback and the
/// service uses it again before saving.
class EmployeeValidator {
  const EmployeeValidator._();

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _guid = RegExp(
    r'^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
  );
  static final _employeeId = RegExp(r'^EMP-\d{4,}$');

  /// Returns one message per bad field. An empty map means the draft is valid.
  /// [isCreate] is false on edit, because EntraObjectID cannot change then.
  static Map<EmployeeFormField, String> validate(
    EmployeeDraft input, {
    required bool isCreate,
  }) {
    final d = input.normalized();
    final errors = <EmployeeFormField, String>{};

    if (d.name.isEmpty) {
      errors[EmployeeFormField.name] = 'Enter the name.';
    } else if (d.name.length > 255) {
      errors[EmployeeFormField.name] = 'The name is too long.';
    }

    if (d.email.isEmpty) {
      errors[EmployeeFormField.email] = 'Enter the email.';
    } else if (!_email.hasMatch(d.email)) {
      errors[EmployeeFormField.email] = 'Enter a valid email address.';
    }

    if (isCreate) {
      if (d.entraObjectId.isEmpty) {
        errors[EmployeeFormField.entraObjectId] = 'Enter the Object ID.';
      } else if (!_guid.hasMatch(d.entraObjectId)) {
        errors[EmployeeFormField.entraObjectId] =
            'The Object ID must look like 6417b3d2-3445-49d5-b8ad-1471efaad5a6.';
      }
    }

    if (!employeeDepartments.contains(d.department)) {
      errors[EmployeeFormField.department] = 'Choose a department.';
    }

    if (!AppRole.labels.contains(d.appRole)) {
      errors[EmployeeFormField.appRole] = 'Choose a role.';
    }

    if (d.managerEmployeeId.isNotEmpty &&
        !_employeeId.hasMatch(d.managerEmployeeId)) {
      errors[EmployeeFormField.managerEmployeeId] =
          'Use the format EMP-0001, or leave it empty.';
    }

    return errors;
  }
}
