import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/models/employee_draft.dart';
import 'package:it_management_portal/services/employee_validator.dart';

EmployeeDraft draft({
  String name = 'Siti',
  String email = 'siti@sqlacc.onmicrosoft.com',
  String objectId = '6417b3d2-3445-49d5-b8ad-1471efaad5a6',
  String department = 'IT',
  String role = 'Employee',
  String manager = '',
}) =>
    EmployeeDraft(
      name: name,
      email: email,
      entraObjectId: objectId,
      department: department,
      appRole: role,
      managerEmployeeId: manager,
    );

void main() {
  Map<EmployeeFormField, String> check(EmployeeDraft d, {bool create = true}) =>
      EmployeeValidator.validate(d, isCreate: create);

  test('a good draft has no errors', () {
    expect(check(draft()), isEmpty);
  });

  test('name and email are required and checked', () {
    expect(check(draft(name: '  ')), contains(EmployeeFormField.name));
    expect(check(draft(email: '')), contains(EmployeeFormField.email));
    expect(check(draft(email: 'not-an-email')), contains(EmployeeFormField.email));
  });

  test('Object ID must be a GUID on create, and is ignored on edit', () {
    expect(
      check(draft(objectId: '123213')),
      contains(EmployeeFormField.entraObjectId),
    );
    expect(check(draft(objectId: ''), create: false), isEmpty);
  });

  test('department and role must be real choices', () {
    expect(check(draft(department: 'Sales')), contains(EmployeeFormField.department));
    expect(check(draft(department: '')), contains(EmployeeFormField.department));
    expect(check(draft(role: 'Boss')), contains(EmployeeFormField.appRole));
  });

  test('manager id is optional but must have the EMP-0001 format', () {
    expect(check(draft(manager: '')), isEmpty);
    expect(check(draft(manager: 'emp-0002')), isEmpty);
    expect(check(draft(manager: 'bob')), contains(EmployeeFormField.managerEmployeeId));
  });
}
