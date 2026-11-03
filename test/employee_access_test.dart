import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/models/app_role.dart';
import 'package:it_management_portal/services/employee_access.dart';

void main() {
  test('Management and Admin can manage', () {
    expect(const EmployeeAccess(AppRole.management).canManage, isTrue);
    expect(const EmployeeAccess(AppRole.admin).canManage, isTrue);
  });

  test('Team Lead sees details but cannot manage', () {
    const access = EmployeeAccess(AppRole.teamLead);
    expect(access.canSeeDetails, isTrue);
    expect(access.canManage, isFalse);
  });

  test('Employee gets the limited profile only', () {
    const access = EmployeeAccess(AppRole.employee);
    expect(access.canSeeDetails, isFalse);
    expect(access.canManage, isFalse);
  });

  test('unknown roles get the lowest access', () {
    expect(AppRole.parse('Boss'), AppRole.employee);
    expect(AppRole.parse(''), AppRole.employee);
    expect(AppRole.parse('TeamLead'), AppRole.teamLead);
  });
}
