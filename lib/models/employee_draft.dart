import '../core/configuration/app_config.dart';

/// The values a person types into the employee form.
class EmployeeDraft {
  const EmployeeDraft({
    required this.name,
    required this.email,
    required this.entraObjectId,
    required this.department,
    required this.appRole,
    this.jobTitle = '',
    this.joinDate,
    this.managerEmployeeId = '',
  });

  final String name;
  final String email;
  final String entraObjectId;
  final String department;
  final String appRole;
  final String jobTitle;

  /// Date only. Only the year, month and day are used.
  final DateTime? joinDate;
  final String managerEmployeeId;

  /// Trims text. Object IDs are stored in lower case.
  EmployeeDraft normalized() => EmployeeDraft(
        name: name.trim(),
        email: email.trim(),
        entraObjectId: entraObjectId.trim().toLowerCase(),
        department: department,
        appRole: appRole,
        jobTitle: jobTitle.trim(),
        joinDate: joinDate,
        managerEmployeeId: managerEmployeeId.trim().toUpperCase(),
      );

  /// Fields for a new row. [employeeId] and [createdAtUtc] come from the service.
  Map<String, Object?> toCreateFields({
    required String employeeId,
    required DateTime createdAtUtc,
  }) =>
      {
        SpFields.title: name,
        SpFields.employeeId: employeeId,
        SpFields.email: email,
        SpFields.entraObjectId: entraObjectId,
        SpFields.department: department,
        SpFields.appRole: appRole,
        SpFields.isActive: true,
        SpFields.createdAtUtc: createdAtUtc.toUtc().toIso8601String(),
        if (jobTitle.isNotEmpty) SpFields.jobTitle: jobTitle,
        if (joinDate != null) SpFields.joinDate: _dateOnly(joinDate!),
        if (managerEmployeeId.isNotEmpty)
          SpFields.managerEmployeeId: managerEmployeeId,
      };

  /// Fields for an edit. EmployeeID and EntraObjectID never change.
  /// Empty optional values are sent as null so they are cleared.
  Map<String, Object?> toUpdateFields() => {
        SpFields.title: name,
        SpFields.email: email,
        SpFields.department: department,
        SpFields.appRole: appRole,
        SpFields.jobTitle: jobTitle.isEmpty ? null : jobTitle,
        SpFields.joinDate: joinDate == null ? null : _dateOnly(joinDate!),
        SpFields.managerEmployeeId:
            managerEmployeeId.isEmpty ? null : managerEmployeeId,
      };

  static String _dateOnly(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}T00:00:00Z';
  }
}
