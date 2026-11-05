import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/data/api/graph_client.dart';
import 'package:it_management_portal/data/repositories/issue_repository.dart';
import 'package:it_management_portal/models/app_user.dart';
import 'package:it_management_portal/models/issue.dart';
import 'package:it_management_portal/models/task_enums.dart';
import 'package:it_management_portal/services/issue_codes.dart';
import 'package:it_management_portal/services/issue_service.dart';
import 'package:it_management_portal/services/issue_workflow.dart';

import 'task_service_test.dart' show FakeEmployees, emp, userOf;

IssueItem issue({
  IssueStatus status = IssueStatus.open,
  String reporter = 'EMP-0003',
  String assignee = '',
  DateTime? resolvedAt,
}) =>
    IssueItem(
      itemId: '7',
      etag: '"7,1"',
      issueCode: 'ISS-2026-00001',
      title: 'Server down',
      description: 'Cannot reach it',
      issueType: 'Infrastructure',
      priority: TaskPriority.high,
      status: status,
      reportedByEmployeeId: reporter,
      reportedAtUtc: DateTime.utc(2026, 11, 3),
      assignedEmployeeId: assignee,
      resolvedAtUtc: resolvedAt,
    );

IssueDraft draft({
  String title = 'Server down',
  String description = 'Cannot reach it',
  String type = 'Infrastructure',
  String priority = 'High',
  String task = '',
}) =>
    IssueDraft(
      title: title,
      description: description,
      issueType: type,
      priority: priority,
      relatedTaskCode: task,
    );

class FakeIssues implements IssueDirectory {
  String? highest;
  final createCalls = <Map<String, Object?>>[];
  final updateCalls = <Map<String, Object?>>[];
  final createErrors = <GraphException>[];
  GraphException? updateError;

  @override
  Future<IssuePage> listPage({
    String? status,
    String? assignedEmployeeId,
    String? nextLink,
  }) async =>
      const IssuePage(items: []);

  @override
  Future<String?> highestIssueCode() async => highest;

  @override
  Future<IssueItem> create(Map<String, Object?> fields) async {
    createCalls.add(fields);
    if (createErrors.isNotEmpty) throw createErrors.removeAt(0);
    return issue();
  }

  @override
  Future<IssueItem> update({
    required IssueItem current,
    required Map<String, Object?> fields,
  }) async {
    updateCalls.add(fields);
    if (updateError != null) throw updateError!;
    return current;
  }
}

void main() {
  late FakeIssues issues;
  late FakeEmployees employees;
  late IssueService service;
  late AppUser lead; // EMP-0001, Team Lead
  late AppUser worker; // EMP-0002, will be the assignee
  late AppUser reporter; // EMP-0003
  late AppUser stranger; // EMP-0004

  setUp(() {
    issues = FakeIssues();
    employees = FakeEmployees();
    final l = emp('1', role: 'TeamLead');
    final w = emp('2');
    final r = emp('3');
    final s = emp('4');
    employees.rows.addAll([l, w, r, s, emp('5', active: false)]);
    lead = userOf(l);
    worker = userOf(w);
    reporter = userOf(r);
    stranger = userOf(s);
    service = IssueService(
      issues,
      employees,
      clock: () => DateTime.utc(2026, 11, 3, 2),
    );
  });

  Future<IssueRuleException> ruleError(Future<Object?> Function() run) async {
    try {
      await run();
    } on IssueRuleException catch (e) {
      return e;
    }
    fail('Expected an IssueRuleException');
  }

  group('create', () {
    test('anyone can report; it starts Open', () async {
      await service.create(stranger, draft(task: ' task-2026-00007 '));
      final f = issues.createCalls.single;
      expect(f['IssueCode'], 'ISS-2026-00001');
      expect(f['Status'], 'Open');
      expect(f['ReportedByEmployeeID'], 'EMP-0004');
      expect(f['ReportedAtUTC'], '2026-11-03T02:00:00.000Z');
      expect(f['RelatedTaskCode'], 'TASK-2026-00007');
      expect(f.containsKey('AssignedEmployeeID'), isFalse);
    });

    test('the code follows the highest one', () async {
      issues.highest = 'ISS-2026-00041';
      await service.create(worker, draft());
      expect(issues.createCalls.single['IssueCode'], 'ISS-2026-00042');
    });

    test('bad fields are refused before saving', () async {
      final e = await ruleError(
        () => service.create(
          worker,
          draft(title: ' ', description: '', type: '', priority: 'Urgent', task: 'T-1'),
        ),
      );
      expect(e.fieldErrors.keys, containsAll(IssueFormField.values.where((f) => f != IssueFormField.project)));
      expect(issues.createCalls, isEmpty);
    });

    test('a duplicate code is retried, up to 3 times', () async {
      final dup = GraphException(statusCode: 409, userMessage: 'duplicate');
      issues.createErrors.addAll([dup, dup]);
      await service.create(worker, draft());
      expect(issues.createCalls, hasLength(3));
      issues.createCalls.clear();
      issues.createErrors.addAll([dup, dup, dup]);
      await ruleError(() => service.create(worker, draft()));
      expect(issues.createCalls, hasLength(3));
    });

    test('other errors are not retried', () async {
      issues.createErrors.add(GraphException(statusCode: 500, userMessage: 'x'));
      await expectLater(
        service.create(worker, draft()),
        throwsA(isA<GraphException>()),
      );
      expect(issues.createCalls, hasLength(1));
    });
  });

  group('edit', () {
    test('the reporter can edit an Open issue', () async {
      await service.update(reporter, issue(), draft(title: 'New title'));
      expect(issues.updateCalls.single['Title'], 'New title');
    });

    test('the reporter cannot edit once it is assigned', () async {
      await ruleError(
        () => service.update(reporter, issue(status: IssueStatus.assigned), draft()),
      );
    });

    test('a stranger cannot edit', () async {
      await ruleError(() => service.update(stranger, issue(), draft()));
    });

    test('a lead can edit until Closed', () async {
      await service.update(lead, issue(status: IssueStatus.waiting), draft());
      await ruleError(
        () => service.update(lead, issue(status: IssueStatus.closed), draft()),
      );
      expect(issues.updateCalls, hasLength(1));
    });

    test('optional codes are cleared with null', () async {
      await service.update(lead, issue(), draft());
      final f = issues.updateCalls.single;
      expect(f.containsKey('RelatedTaskCode'), isTrue);
      expect(f['RelatedTaskCode'], isNull);
    });
  });

  group('assign', () {
    test('a lead assigns an Open issue; it becomes Assigned', () async {
      await service.assign(lead, issue(), 'emp-0002');
      final f = issues.updateCalls.single;
      expect(f['AssignedEmployeeID'], 'EMP-0002');
      expect(f['Status'], 'Assigned');
    });

    test('reassigning keeps the status', () async {
      await service.assign(
        lead,
        issue(status: IssueStatus.investigating, assignee: 'EMP-0002'),
        'EMP-0004',
      );
      final f = issues.updateCalls.single;
      expect(f['AssignedEmployeeID'], 'EMP-0004');
      expect(f.containsKey('Status'), isFalse);
    });

    test('not for non-leads, inactive or unknown people, or Resolved', () async {
      await ruleError(() => service.assign(worker, issue(), 'EMP-0002'));
      await ruleError(() => service.assign(lead, issue(), 'EMP-0005'));
      await ruleError(() => service.assign(lead, issue(), 'EMP-0099'));
      await ruleError(
        () => service.assign(lead, issue(status: IssueStatus.resolved), 'EMP-0002'),
      );
      expect(issues.updateCalls, isEmpty);
    });
  });

  group('status changes', () {
    test('the assignee runs the investigation', () async {
      final a = issue(status: IssueStatus.assigned, assignee: 'EMP-0002');
      await service.changeStatus(worker, a, IssueStatus.investigating);
      expect(issues.updateCalls.last['Status'], 'Investigating');

      final inv = issue(status: IssueStatus.investigating, assignee: 'EMP-0002');
      await service.changeStatus(worker, inv, IssueStatus.waiting, remarks: 'Vendor');
      expect(issues.updateCalls.last['ResolutionRemarks'], 'Waiting: Vendor');

      final w = issue(status: IssueStatus.waiting, assignee: 'EMP-0002');
      await service.changeStatus(worker, w, IssueStatus.investigating);
      expect(issues.updateCalls.last['Status'], 'Investigating');
    });

    test('resolving needs remarks and stores the time', () async {
      final inv = issue(status: IssueStatus.investigating, assignee: 'EMP-0002');
      await ruleError(
        () => service.changeStatus(worker, inv, IssueStatus.resolved, remarks: ' '),
      );
      await service.changeStatus(
        worker,
        inv,
        IssueStatus.resolved,
        remarks: ' Restarted service ',
      );
      final f = issues.updateCalls.single;
      expect(f['Status'], 'Resolved');
      expect(f['ResolutionRemarks'], 'Restarted service');
      expect(f['ResolvedAtUTC'], '2026-11-03T02:00:00.000Z');
    });

    test('only the assignee works on it, not the reporter or a stranger',
        () async {
      final a = issue(status: IssueStatus.assigned, assignee: 'EMP-0002');
      await ruleError(
        () => service.changeStatus(reporter, a, IssueStatus.investigating),
      );
      await ruleError(
        () => service.changeStatus(stranger, a, IssueStatus.investigating),
      );
      expect(issues.updateCalls, isEmpty);
    });

    test('the reporter or a lead confirms and closes; resolution text stays',
        () async {
      final r = issue(status: IssueStatus.resolved, assignee: 'EMP-0002');
      await service.changeStatus(reporter, r, IssueStatus.closed);
      var f = issues.updateCalls.last;
      expect(f['Status'], 'Closed');
      expect(f.containsKey('ResolutionRemarks'), isFalse);
      await service.changeStatus(lead, r, IssueStatus.closed);
      expect(issues.updateCalls, hasLength(2));
      await ruleError(() => service.changeStatus(stranger, r, IssueStatus.closed));
    });

    test('reopening needs a reason and clears the resolved time', () async {
      final r = issue(
        status: IssueStatus.resolved,
        assignee: 'EMP-0002',
        resolvedAt: DateTime.utc(2026, 11, 3),
      );
      await ruleError(
        () => service.changeStatus(reporter, r, IssueStatus.investigating),
      );
      await service.changeStatus(
        reporter,
        r,
        IssueStatus.investigating,
        remarks: 'Still failing',
      );
      final f = issues.updateCalls.single;
      expect(f['ResolutionRemarks'], 'Reopened: Still failing');
      expect(f.containsKey('ResolvedAtUTC'), isTrue);
      expect(f['ResolvedAtUTC'], isNull);
    });

    test('a lead can close without fixing, with a reason', () async {
      await ruleError(
        () => service.changeStatus(lead, issue(), IssueStatus.closed),
      );
      await service.changeStatus(
        lead,
        issue(),
        IssueStatus.closed,
        remarks: 'Duplicate of ISS-2026-00009',
      );
      final f = issues.updateCalls.single;
      expect(f['ResolutionRemarks'], 'Closed: Duplicate of ISS-2026-00009');
    });

    test('Closed is final and jumps are refused', () async {
      for (final to in IssueStatus.values) {
        await ruleError(
          () => service.changeStatus(
            lead,
            issue(status: IssueStatus.closed),
            to,
            remarks: 'x',
          ),
        );
      }
      await ruleError(
        () => service.changeStatus(
          lead,
          issue(status: IssueStatus.open),
          IssueStatus.resolved,
          remarks: 'x',
        ),
      );
      expect(issues.updateCalls, isEmpty);
    });

    test('a stale ETag gives a clear message', () async {
      issues.updateError =
          GraphException(statusCode: 412, userMessage: 'precondition');
      final e = await ruleError(
        () => service.changeStatus(
          lead,
          issue(status: IssueStatus.resolved),
          IssueStatus.closed,
        ),
      );
      expect(e.message, contains('Someone else'));
    });
  });

  group('workflow table', () {
    test('every target status is offered once per person', () {
      final moves = IssueWorkflow.movesFor(
        IssueStatus.resolved,
        {IssueActor.reporter, IssueActor.lead},
      );
      expect(moves.map((m) => m.to), [IssueStatus.closed, IssueStatus.investigating]);
    });

    test('Closed has no moves', () {
      expect(
        IssueWorkflow.movesFor(IssueStatus.closed, IssueActor.values.toSet()),
        isEmpty,
      );
    });
  });

  test('issue codes', () {
    expect(IssueCodes.next(null, 2026), 'ISS-2026-00001');
    expect(IssueCodes.next('ISS-2026-00009', 2026), 'ISS-2026-00010');
    expect(IssueCodes.next('ISS-2027-00001', 2026), isNull);
    expect(IssueCodes.next('TASK-2026-00001', 2026), isNull);
  });
}
