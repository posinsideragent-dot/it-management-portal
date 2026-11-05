import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/services/employee_ids.dart';

void main() {
  test('first id for an empty list', () {
    expect(EmployeeIds.next(null), 'EMP-0001');
    expect(EmployeeIds.next(''), 'EMP-0001');
  });

  test('next id is highest plus one, with 4 digits', () {
    expect(EmployeeIds.next('EMP-0001'), 'EMP-0002');
    expect(EmployeeIds.next('EMP-0009'), 'EMP-0010');
    expect(EmployeeIds.next('EMP-9999'), 'EMP-10000');
  });

  test('a badly formatted id gives null', () {
    expect(EmployeeIds.next('8888'), isNull);
  });
}
