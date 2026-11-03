import '../models/app_role.dart';
import '../models/app_user.dart';

/// What the app shows each role in the Employees module.
///
/// This is for usability. It is not security: SharePoint permissions are.
/// Management and Admin manage employees. Team Leads see all details.
/// Employees see a limited profile (name, job title, department).
class EmployeeAccess {
  const EmployeeAccess(this.role);

  factory EmployeeAccess.forUser(AppUser user) =>
      EmployeeAccess(AppRole.parse(user.role));

  final AppRole role;

  bool get canManage => role == AppRole.management || role == AppRole.admin;

  bool get canSeeDetails => role != AppRole.employee;
}
