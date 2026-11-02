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
  });

  final String itemId;
  final String employeeId;
  final String name;
  final String email;
  final String entraObjectId;
  final String appRole;
  final bool isActive;

  /// [item] is a Graph list item that was requested with $expand=fields.
  factory Employee.fromGraphItem(Map<String, dynamic> item) {
    final fields = (item['fields'] as Map<String, dynamic>?) ?? const {};
    String text(String key) => (fields[key] ?? '').toString();
    return Employee(
      itemId: item['id'].toString(),
      employeeId: text(SpFields.employeeId),
      name: text(SpFields.title),
      email: text(SpFields.email),
      entraObjectId: text(SpFields.entraObjectId),
      appRole: text(SpFields.appRole),
      isActive: fields[SpFields.isActive] == true,
    );
  }
}
