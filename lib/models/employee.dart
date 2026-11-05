import '../core/configuration/app_config.dart';

/// One row of the IT_Employees list.
class Employee {
  const Employee({
    required this.itemId,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.entraObjectId,
    required this.appRole,
    required this.isActive,
    this.etag = '',
    this.jobTitle = '',
    this.department = '',
    this.joinDate,
    this.managerEmployeeId = '',
    this.createdAtUtc,
  });

  /// SharePoint list item id (not the business EmployeeID).
  final String itemId;

  /// Business id such as EMP-0001. Unique. Never changes.
  final String employeeId;
  final String name;
  final String email;
  final String entraObjectId;
  final String appRole;
  final bool isActive;

  /// Sent as If-Match on updates, so two people cannot overwrite each other.
  final String etag;
  final String jobTitle;
  final String department;

  /// Date only. Held as UTC midnight of that calendar date.
  final DateTime? joinDate;
  final String managerEmployeeId;
  final DateTime? createdAtUtc;

  /// [item] is a Graph list item that was requested with $expand=fields.
  factory Employee.fromGraphItem(Map<String, dynamic> item) {
    final fields = (item['fields'] as Map<String, dynamic>?) ?? const {};
    String text(String key) => (fields[key] ?? '').toString();
    return Employee(
      itemId: item['id'].toString(),
      etag: (item['eTag'] ?? item['@odata.etag'] ?? '').toString(),
      employeeId: text(SpFields.employeeId),
      name: text(SpFields.title),
      email: text(SpFields.email),
      entraObjectId: text(SpFields.entraObjectId),
      appRole: text(SpFields.appRole),
      isActive: fields[SpFields.isActive] == true,
      jobTitle: text(SpFields.jobTitle),
      department: text(SpFields.department),
      joinDate: _parseUtc(fields[SpFields.joinDate]),
      managerEmployeeId: text(SpFields.managerEmployeeId),
      createdAtUtc: _parseUtc(fields[SpFields.createdAtUtc]),
    );
  }
}

DateTime? _parseUtc(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toUtc();
}
