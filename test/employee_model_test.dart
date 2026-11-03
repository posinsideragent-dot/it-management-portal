import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/data/api/graph_client.dart';
import 'package:it_management_portal/models/employee.dart';
import 'package:it_management_portal/models/employee_draft.dart';

void main() {
  test('Employee reads a Graph list item', () {
    final e = Employee.fromGraphItem({
      'id': '7',
      'eTag': '"abc,3"',
      'fields': {
        'Title': 'Siti',
        'EmployeeID': 'EMP-0007',
        'Email': 'siti@x.com',
        'EntraObjectID': 'oid',
        'AppRole': 'TeamLead',
        'IsActive': true,
        'Department': 'IT',
        'JoinDate': '2026-01-05T00:00:00Z',
      },
    });
    expect(e.itemId, '7');
    expect(e.etag, '"abc,3"');
    expect(e.isActive, isTrue);
    expect(e.joinDate, DateTime.utc(2026, 1, 5));
    expect(e.jobTitle, '');
  });

  test('create fields hold the id, active flag and UTC time', () {
    const draft = EmployeeDraft(
      name: 'Siti',
      email: 's@x.com',
      entraObjectId: 'oid',
      department: 'IT',
      appRole: 'Employee',
    );
    final fields = draft.toCreateFields(
      employeeId: 'EMP-0002',
      createdAtUtc: DateTime.utc(2026, 11, 3, 6),
    );
    expect(fields['EmployeeID'], 'EMP-0002');
    expect(fields['IsActive'], true);
    expect(fields['CreatedAtUTC'], '2026-11-03T06:00:00.000Z');
    expect(fields.containsKey('JobTitle'), isFalse);
  });

  test('update fields never include the two unique ids and clear empties', () {
    const draft = EmployeeDraft(
      name: 'Siti',
      email: 's@x.com',
      entraObjectId: 'oid',
      department: 'IT',
      appRole: 'Employee',
    );
    final fields = draft.toUpdateFields();
    expect(fields.containsKey('EmployeeID'), isFalse);
    expect(fields.containsKey('EntraObjectID'), isFalse);
    expect(fields['JobTitle'], isNull);
    expect(fields.containsKey('JoinDate'), isTrue);
  });

  test('only the Graph host is trusted for paging links', () {
    expect(
      GraphClient.isTrustedGraphUrl('https://graph.microsoft.com/v1.0/x?y=1'),
      isTrue,
    );
    expect(GraphClient.isTrustedGraphUrl('https://evil.example/v1.0/x'), isFalse);
    expect(GraphClient.isTrustedGraphUrl('http://graph.microsoft.com/x'), isFalse);
    expect(
      GraphClient.isTrustedGraphUrl('https://graph.microsoft.com.evil.io/x'),
      isFalse,
    );
  });
}
