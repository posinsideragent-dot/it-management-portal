/// Roles stored in IT_Employees.AppRole.
///
/// Roles drive menus and buttons only. SharePoint permissions are the
/// real security boundary.
enum AppRole {
  management('Management'),
  teamLead('TeamLead'),
  employee('Employee'),
  admin('Admin');

  const AppRole(this.label);

  /// The exact Choice value stored in SharePoint.
  final String label;

  /// Unknown or empty values get the lowest role (least privilege).
  static AppRole parse(String value) => AppRole.values.firstWhere(
        (role) => role.label == value,
        orElse: () => AppRole.employee,
      );

  static List<String> get labels =>
      AppRole.values.map((role) => role.label).toList();
}

/// Choice values for IT_Employees.Department.
const employeeDepartments = <String>['IT', 'Development'];
