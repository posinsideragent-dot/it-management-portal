import 'employee.dart';
import 'user_profile.dart';

/// A signed-in person who is also an active row in IT_Employees.
///
/// The role is for menus only. SharePoint permissions are the real security.
class AppUser {
  const AppUser({required this.profile, required this.employee});

  final UserProfile profile;
  final Employee employee;

  String get name => employee.name.isEmpty ? profile.displayName : employee.name;
  String get role => employee.appRole;
}
