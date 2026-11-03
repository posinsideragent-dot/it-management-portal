import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/data/api/graph_client.dart';
import 'package:it_management_portal/data/repositories/employee_repository.dart';
import 'package:it_management_portal/models/app_user.dart';
import 'package:it_management_portal/models/employee.dart';
import 'package:it_management_portal/models/employee_draft.dart';
import 'package:it_management_portal/models/employee_page.dart';
import 'package:it_management_portal/models/user_profile.dart';
import 'package:it_management_portal/services/employee_service.dart';
import 'package:it_management_portal/services/employee_validator.dart';

Employee emp(
  String id, {
  String role = 'Employee',
  bool active = true,
  String oid = 'oid',
}) =>
    Employee(
      itemId: id,
      etag: '"e$id"',
      employeeId: 'EMP-000$id',
      name: 'Name $id',
      email: 'e$id@x.com',
      entraObjectId: oid,
      appRole: role,
      isActive: active,
      department: 'IT',
    );

AppUser userOf(Employee e) => AppUser(
      profile: UserProfile(
        objectId: e.entraObjectId,
        displayName: e.name,
        userPrincipalName: e.email,
      ),
      employee: e,
    );

class FakeDirectory implements EmployeeDirectory {
  final rows = <Employee>[];
  final createCalls = <Map<String, Object?>>[];
  final updateCalls = <Map<String, Object?>>[];

  /// Errors thrown by successive create calls, then normal behaviour.
  final createErrors = <GraphException>[];
  GraphException? updateError;

  @override
  Future<EmployeePage> listPage({bool? isActive, String? nextLink}) async =>
      EmployeePage(items: rows);

  @override
  Future<Employee?> findByEntraObjectId(String objectId) async {
    for (final e in rows) {
      if (e.entraObjectId == objectId) return e;
    }
    return null;
  }

  @override
  Future<Employee?> findByEmployeeId(String employeeId) async {
    for (final e in rows) {
      if (e.employeeId == employeeId) return e;
    }
    return null;
  }

  @override
  Future<String?> highestEmployeeId() async {
    if (rows.isEmpty) return null;
    final ids = rows.map((e) => e.employeeId).toList()..sort();
    return ids.last;
  }

  @override
  Future<Employee> create(Map<String, Object?> fields) async {
    createCalls.add(fields);
    if (createErrors.isNotEmpty) throw createErrors.removeAt(0);
    final e = Employee(
      itemId: '${rows.length + 1}',
      employeeId: fields['EmployeeID']! as String,
      name: fields['Title']! as String,
      email: fields['Email']! as String,
      entraObjectId: fields['EntraObjectID']! as String,
      appRole: fields['AppRole']! as String,
      isActive: true,
    );
    rows.add(e);
    return e;
  }

  @override
  Future<Employee> update({
    required Employee current,
    required Map<String, Object?> fields,
  }) async {
    updateCalls.add(fields);
    if (updateError != null) throw updateError!;
    return current;
  }
}

EmployeeDraft goodDraft({String oid = '6417b3d2-3445-49d5-b8ad-1471efaad5a6'}) =>
    EmployeeDraft(
      name: 'Siti',
      email: 'siti@x.com',
      entraObjectId: oid,
      department: 'IT',
      appRole: 'Employee',
    );

const workerOid = '11111111-1111-1111-1111-111111111111';

void main() {
  late FakeDirectory directory;
  late EmployeeService service;
  late AppUser manager;
  late AppUser worker;

  setUp(() {
    directory = FakeDirectory();
    service = EmployeeService(directory, clock: () => DateTime.utc(2026, 11, 3));
    final m = emp('1', role: 'Management', oid: 'oid-m');
    final w = emp('2', role: 'Employee', oid: workerOid);
    directory.rows.addAll([m, w]);
    manager = userOf(m);
    worker = userOf(w);
  });

  Future<EmployeeRuleException> ruleError(Future<Object?> Function() run) async {
    try {
      await run();
    } on EmployeeRuleException catch (e) {
      return e;
    }
    fail('Expected an EmployeeRuleException');
  }

  group('create', () {
    test('manager creates with the next EmployeeID', () async {
      final created = await service.create(manager, goodDraft());
      expect(created.employeeId, 'EMP-0003');
      expect(directory.createCalls.single['IsActive'], true);
    });

    test('an Employee cannot create', () async {
      final e = await ruleError(() => service.create(worker, goodDraft()));
      expect(e.message, contains('Management or Admin'));
      expect(directory.createCalls, isEmpty);
    });

    test('bad input is rejected with field errors, nothing is sent', () async {
      final e = await ruleError(
        () => service.create(manager, goodDraft(oid: 'bad')),
      );
      expect(e.fieldErrors, contains(EmployeeFormField.entraObjectId));
      expect(directory.createCalls, isEmpty);
    });

    test('an already registered Object ID is refused', () async {
      final e = await ruleError(
        () => service.create(manager, goodDraft(oid: workerOid)),
      );
      expect(e.message, contains('already registered'));
    });

    test('a taken EmployeeID is retried once with a fresh number', () async {
      directory.createErrors.add(
        GraphException(statusCode: 409, userMessage: 'Conflict'),
      );
      final created = await service.create(manager, goodDraft());
      expect(directory.createCalls.length, 2);
      expect(created.employeeId, 'EMP-0003');
    });

    test('a server error is not retried', () async {
      directory.createErrors.add(
        GraphException(statusCode: 500, userMessage: 'Down'),
      );
      await expectLater(
        service.create(manager, goodDraft()),
        throwsA(isA<GraphException>()),
      );
      expect(directory.createCalls.length, 1);
    });

    test('gives up after 3 duplicate answers', () async {
      for (var i = 0; i < 3; i++) {
        directory.createErrors.add(
          GraphException(statusCode: 409, userMessage: 'Conflict'),
        );
      }
      final e = await ruleError(() => service.create(manager, goodDraft()));
      expect(e.message, contains('free EmployeeID'));
      expect(directory.createCalls.length, 3);
    });

    test('an unknown manager id is refused', () async {
      final draft = EmployeeDraft(
        name: 'Siti',
        email: 'siti@x.com',
        entraObjectId: '6417b3d2-3445-49d5-b8ad-1471efaad5a6',
        department: 'IT',
        appRole: 'Employee',
        managerEmployeeId: 'EMP-0099',
      );
      final e = await ruleError(() => service.create(manager, draft));
      expect(e.fieldErrors, contains(EmployeeFormField.managerEmployeeId));
    });
  });

  group('update and deactivate', () {
    test('manager edits another employee', () async {
      await service.update(manager, directory.rows[1], goodDraft());
      expect(directory.updateCalls.single['Title'], 'Siti');
    });

    test('cannot change your own role', () async {
      final draft = EmployeeDraft(
        name: 'Name 1',
        email: 'e1@x.com',
        entraObjectId: 'oid-m',
        department: 'IT',
        appRole: 'Employee',
      );
      final e = await ruleError(
        () => service.update(manager, directory.rows[0], draft),
      );
      expect(e.message, contains('own role'));
    });

    test('cannot be your own manager', () async {
      final draft = EmployeeDraft(
        name: 'Name 2',
        email: 'e2@x.com',
        entraObjectId: workerOid,
        department: 'IT',
        appRole: 'Employee',
        managerEmployeeId: 'EMP-0002',
      );
      final e = await ruleError(
        () => service.update(manager, directory.rows[1], draft),
      );
      expect(e.fieldErrors, contains(EmployeeFormField.managerEmployeeId));
    });

    test('a stale ETag becomes a clear message', () async {
      directory.updateError = GraphException(
        statusCode: 412,
        userMessage: 'changed',
      );
      final e = await ruleError(
        () => service.update(manager, directory.rows[1], goodDraft()),
      );
      expect(e.message, contains('Someone else changed'));
    });

    test('deactivate then reactivate', () async {
      await service.setActive(manager, directory.rows[1], active: false);
      expect(directory.updateCalls.last['IsActive'], false);
      await service.setActive(
        manager,
        emp('2', active: false),
        active: true,
      );
      expect(directory.updateCalls.last['IsActive'], true);
    });

    test('no call when the state is already right', () async {
      await service.setActive(manager, directory.rows[1], active: true);
      expect(directory.updateCalls, isEmpty);
    });

    test('cannot deactivate yourself', () async {
      final e = await ruleError(
        () => service.setActive(manager, directory.rows[0], active: false),
      );
      expect(e.message, contains('own account'));
    });

    test('an Employee cannot deactivate anyone', () async {
      final e = await ruleError(
        () => service.setActive(worker, directory.rows[0], active: false),
      );
      expect(e.message, contains('Management or Admin'));
    });
  });
}
