import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/data/api/graph_client.dart';
import 'package:it_management_portal/data/repositories/employee_repository.dart';
import 'package:it_management_portal/data/repositories/task_repository.dart';
import 'package:it_management_portal/models/app_user.dart';
import 'package:it_management_portal/models/employee.dart';
import 'package:it_management_portal/models/employee_page.dart';
import 'package:it_management_portal/models/task_draft.dart';
import 'package:it_management_portal/models/task_enums.dart';
import 'package:it_management_portal/models/task_item.dart';
import 'package:it_management_portal/models/task_page.dart';
import 'package:it_management_portal/models/user_profile.dart';
import 'package:it_management_portal/services/task_service.dart';
import 'package:it_management_portal/services/task_validator.dart';

Employee emp(String n, {String role = 'Employee', bool active = true}) =>
    Employee(
      itemId: n,
      employeeId: 'EMP-000$n',
      name: 'Name $n',
      email: 'e$n@x.com',
      entraObjectId: 'oid-$n',
      appRole: role,
      isActive: active,
    );

AppUser userOf(Employee e) => AppUser(
      profile: UserProfile(
        objectId: e.entraObjectId,
        displayName: e.name,
        userPrincipalName: e.email,
      ),
      employee: e,
    );

TaskItem task({
  TaskStatus status = TaskStatus.newTask,
  String assignee = 'EMP-0002',
  DocumentationStatus docs = DocumentationStatus.notRequired,
  String completionRemarks = '',
  DateTime? actualStart,
  double estimate = 8,
  double? proposed,
  double? revised,
  bool? docRequired,
}) =>
    TaskItem(
      itemId: '10',
      etag: '"t,1"',
      taskCode: 'TASK-2026-00001',
      title: 'Fix login',
      description: 'Details',
      taskType: 'Bug Fix',
      assignedEmployeeId: assignee,
      createdByEmployeeId: 'EMP-0001',
      priority: TaskPriority.normal,
      status: status,
      estimatedHours: estimate,
      expectedCompletion: DateTime.utc(2026, 12, 1),
      progress: 0,
      documentationRequired:
          docRequired ?? docs != DocumentationStatus.notRequired,
      proposedEstimatedHours: proposed,
      revisedEstimatedHours: revised,
      documentationStatus: docs,
      completionRemarks: completionRemarks,
      actualStart: actualStart,
    );

class FakeEmployees implements EmployeeDirectory {
  final rows = <Employee>[];

  @override
  Future<Employee?> findByEmployeeId(String employeeId) async {
    for (final e in rows) {
      if (e.employeeId == employeeId) return e;
    }
    return null;
  }

  @override
  Future<Employee?> findByEntraObjectId(String objectId) async => null;

  @override
  Future<EmployeePage> listPage({bool? isActive, String? nextLink}) async =>
      EmployeePage(items: rows);

  @override
  Future<String?> highestEmployeeId() async => null;

  @override
  Future<Employee> create(Map<String, Object?> fields) =>
      throw UnimplementedError();

  @override
  Future<Employee> update({
    required Employee current,
    required Map<String, Object?> fields,
  }) =>
      throw UnimplementedError();
}

class FakeTasks implements TaskDirectory {
  String? highest;
  final createCalls = <Map<String, Object?>>[];
  final updateCalls = <Map<String, Object?>>[];
  final createErrors = <GraphException>[];
  GraphException? updateError;

  @override
  Future<TaskPage> listPage({
    String? status,
    String? assignedEmployeeId,
    String? nextLink,
  }) async =>
      const TaskPage(items: []);

  @override
  Future<String?> highestTaskCode() async => highest;

  @override
  Future<TaskItem> create(Map<String, Object?> fields) async {
    createCalls.add(fields);
    if (createErrors.isNotEmpty) throw createErrors.removeAt(0);
    return task();
  }

  @override
  Future<TaskItem> update({
    required TaskItem current,
    required Map<String, Object?> fields,
  }) async {
    updateCalls.add(fields);
    if (updateError != null) throw updateError!;
    return current;
  }
}

TaskDraft goodDraft({String assignee = 'EMP-0002', double hours = 8}) =>
    TaskDraft(
      title: 'Fix login',
      description: 'Details',
      taskType: 'Bug Fix',
      assignedEmployeeId: assignee,
      priority: 'Normal',
      estimatedHours: hours,
      expectedCompletion: DateTime.utc(2026, 12, 1),
      documentationRequired: false,
    );

void main() {
  late FakeTasks tasks;
  late FakeEmployees employees;
  late TaskService service;
  late AppUser lead; // EMP-0001, Team Lead
  late AppUser worker; // EMP-0002, assignee
  late AppUser other; // EMP-0003, not assigned

  setUp(() {
    tasks = FakeTasks();
    employees = FakeEmployees();
    final l = emp('1', role: 'TeamLead');
    final w = emp('2');
    final o = emp('3');
    employees.rows.addAll([l, w, o]);
    lead = userOf(l);
    worker = userOf(w);
    other = userOf(o);
    service = TaskService(
      tasks,
      employees,
      clock: () => DateTime.utc(2026, 11, 3, 2),
    );
  });

  Future<TaskRuleException> ruleError(Future<Object?> Function() run) async {
    try {
      await run();
    } on TaskRuleException catch (e) {
      return e;
    }
    fail('Expected a TaskRuleException');
  }

  group('create', () {
    test('a lead creates the first task of the year', () async {
      await service.create(lead, goodDraft());
      final f = tasks.createCalls.single;
      expect(f['TaskCode'], 'TASK-2026-00001');
      expect(f['CreatedByEmployeeID'], 'EMP-0001');
      expect(f['Status'], 'New');
    });

    test('the next code follows the highest one', () async {
      tasks.highest = 'TASK-2026-00041';
      await service.create(lead, goodDraft());
      expect(tasks.createCalls.single['TaskCode'], 'TASK-2026-00042');
    });

    test('an Employee cannot create', () async {
      final e = await ruleError(() => service.create(worker, goodDraft()));
      expect(e.message, contains('Team Lead'));
      expect(tasks.createCalls, isEmpty);
    });

    test('an unknown or inactive assignee is refused', () async {
      var e = await ruleError(
        () => service.create(lead, goodDraft(assignee: 'EMP-0099')),
      );
      expect(e.fieldErrors, contains(TaskFormField.assignee));
      employees.rows[1] = emp('2', active: false);
      e = await ruleError(() => service.create(lead, goodDraft()));
      expect(e.fieldErrors, contains(TaskFormField.assignee));
    });

    test('a duplicate code is retried', () async {
      tasks.createErrors.add(
        GraphException(statusCode: 409, userMessage: 'dup'),
      );
      await service.create(lead, goodDraft());
      expect(tasks.createCalls.length, 2);
    });

    test('a server error is not retried', () async {
      tasks.createErrors.add(
        GraphException(statusCode: 500, userMessage: 'down'),
      );
      await expectLater(
        service.create(lead, goodDraft()),
        throwsA(isA<GraphException>()),
      );
      expect(tasks.createCalls.length, 1);
    });

    test('a past completion date is refused', () async {
      final past = TaskDraft(
        title: 'x',
        description: 'x',
        taskType: 'Bug Fix',
        assignedEmployeeId: 'EMP-0002',
        priority: 'Normal',
        estimatedHours: 1,
        expectedCompletion: DateTime.utc(2026, 1, 1),
        documentationRequired: false,
      );
      final e = await ruleError(() => service.create(lead, past));
      expect(e.fieldErrors, contains(TaskFormField.expectedCompletion));
    });
  });

  group('update', () {
    test('a lead edits a New task and may change the estimate', () async {
      await service.update(lead, task(), goodDraft(hours: 12));
      expect(tasks.updateCalls.single['EstimatedHours'], 12);
    });

    test('the original estimate is locked after acceptance', () async {
      final e = await ruleError(
        () => service.update(
          lead,
          task(status: TaskStatus.accepted),
          goodDraft(hours: 12),
        ),
      );
      expect(e.fieldErrors, contains(TaskFormField.estimate));
      expect(tasks.updateCalls, isEmpty);
    });

    test('the same estimate is accepted after acceptance and not sent',
        () async {
      await service.update(
        lead,
        task(status: TaskStatus.accepted),
        goodDraft(),
      );
      expect(tasks.updateCalls.single.containsKey('EstimatedHours'), isFalse);
    });

    test('final tasks cannot be edited', () async {
      final e = await ruleError(
        () => service.update(
          lead,
          task(status: TaskStatus.completed),
          goodDraft(),
        ),
      );
      expect(e.message, contains('cannot be edited'));
    });

    test('an Employee cannot edit', () async {
      final e =
          await ruleError(() => service.update(worker, task(), goodDraft()));
      expect(e.message, contains('Team Lead'));
    });
  });

  group('status changes', () {
    test('the assignee accepts', () async {
      await service.changeStatus(worker, task(), TaskStatus.accepted);
      expect(tasks.updateCalls.single['Status'], 'Accepted');
    });

    test('someone else cannot accept', () async {
      final e = await ruleError(
        () => service.changeStatus(other, task(), TaskStatus.accepted),
      );
      expect(e.message, contains('cannot change'));
    });

    test('starting sets ActualStart once', () async {
      await service.changeStatus(
        worker,
        task(status: TaskStatus.accepted),
        TaskStatus.inProgress,
      );
      expect(tasks.updateCalls.last.containsKey('ActualStart'), isTrue);
      await service.changeStatus(
        worker,
        task(
          status: TaskStatus.onHold,
          actualStart: DateTime.utc(2026, 11, 1),
        ),
        TaskStatus.inProgress,
      );
      expect(tasks.updateCalls.last.containsKey('ActualStart'), isFalse);
    });

    test('putting on hold needs a reason and keeps it', () async {
      final e = await ruleError(
        () => service.changeStatus(
          worker,
          task(status: TaskStatus.inProgress),
          TaskStatus.onHold,
        ),
      );
      expect(e.message, contains('Reason for holding'));
      await service.changeStatus(
        worker,
        task(status: TaskStatus.inProgress),
        TaskStatus.onHold,
        remarks: 'Waiting for the customer',
      );
      expect(
        tasks.updateCalls.last['BlockerRemarks'],
        'On hold: Waiting for the customer',
      );
    });

    test('submitting needs completion remarks and saves them', () async {
      await expectLater(
        service.changeStatus(
          worker,
          task(status: TaskStatus.inProgress),
          TaskStatus.pendingReview,
          remarks: '  ',
        ),
        throwsA(isA<TaskRuleException>()),
      );
      await service.changeStatus(
        worker,
        task(status: TaskStatus.inProgress),
        TaskStatus.pendingReview,
        remarks: 'Done and tested',
      );
      expect(tasks.updateCalls.last['CompletionRemarks'], 'Done and tested');
    });

    test('a lead approves: completion fields are set', () async {
      await service.changeStatus(
        lead,
        task(status: TaskStatus.pendingReview, completionRemarks: 'Done'),
        TaskStatus.completed,
      );
      final f = tasks.updateCalls.last;
      expect(f['Status'], 'Completed');
      expect(f['ReviewedByEmployeeID'], 'EMP-0001');
      expect(f['Progress'], 100);
      expect(f.containsKey('ActualCompletion'), isTrue);
    });

    test('approval is refused while required documentation is pending',
        () async {
      final e = await ruleError(
        () => service.changeStatus(
          lead,
          task(
            status: TaskStatus.pendingReview,
            completionRemarks: 'Done',
            docs: DocumentationStatus.pending,
          ),
          TaskStatus.completed,
        ),
      );
      expect(e.message, contains('documentation'));
      expect(tasks.updateCalls, isEmpty);
    });

    test('approval is allowed once documentation is submitted', () async {
      await service.changeStatus(
        lead,
        task(
          status: TaskStatus.pendingReview,
          completionRemarks: 'Done',
          docs: DocumentationStatus.submitted,
        ),
        TaskStatus.completed,
      );
      expect(tasks.updateCalls.last['Status'], 'Completed');
    });

    test('approval is refused without completion remarks', () async {
      final e = await ruleError(
        () => service.changeStatus(
          lead,
          task(status: TaskStatus.pendingReview),
          TaskStatus.completed,
        ),
      );
      expect(e.message, contains('Completion remarks'));
    });

    test('return for rework keeps the reason', () async {
      await service.changeStatus(
        lead,
        task(status: TaskStatus.pendingReview, completionRemarks: 'Done'),
        TaskStatus.inProgress,
        remarks: 'Tests missing',
      );
      expect(
        tasks.updateCalls.last['BlockerRemarks'],
        'Returned: Tests missing',
      );
    });

    test('a lead cancels with a reason, an Employee cannot', () async {
      await service.changeStatus(
        lead,
        task(),
        TaskStatus.cancelled,
        remarks: 'No longer needed',
      );
      expect(
        tasks.updateCalls.last['BlockerRemarks'],
        'Cancelled: No longer needed',
      );
      await expectLater(
        service.changeStatus(
          worker,
          task(),
          TaskStatus.cancelled,
          remarks: 'x',
        ),
        throwsA(isA<TaskRuleException>()),
      );
    });

    test('final tasks cannot move', () async {
      final e = await ruleError(
        () => service.changeStatus(
          lead,
          task(status: TaskStatus.completed),
          TaskStatus.inProgress,
        ),
      );
      expect(e.message, contains('cannot change'));
    });

    test('a stale ETag becomes a clear message', () async {
      tasks.updateError =
          GraphException(statusCode: 412, userMessage: 'changed');
      final e = await ruleError(
        () => service.changeStatus(worker, task(), TaskStatus.accepted),
      );
      expect(e.message, contains('Someone else changed'));
    });
  });

  group('progress', () {
    test('the assignee updates progress while In Progress', () async {
      await service.updateProgress(
        worker,
        task(status: TaskStatus.inProgress),
        60,
      );
      expect(tasks.updateCalls.last['Progress'], 60);
    });

    test('others, wrong status and bad values are refused', () async {
      final running = task(status: TaskStatus.inProgress);
      await expectLater(
        service.updateProgress(other, running, 10),
        throwsA(isA<TaskRuleException>()),
      );
      await expectLater(
        service.updateProgress(worker, task(), 10),
        throwsA(isA<TaskRuleException>()),
      );
      await expectLater(
        service.updateProgress(worker, running, 101),
        throwsA(isA<TaskRuleException>()),
      );
      await expectLater(
        service.updateProgress(worker, running, -1),
        throwsA(isA<TaskRuleException>()),
      );
    });
  });
}
