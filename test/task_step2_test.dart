import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/models/app_user.dart';
import 'package:it_management_portal/models/task_draft.dart';
import 'package:it_management_portal/models/task_enums.dart';
import 'package:it_management_portal/services/task_capabilities.dart';
import 'package:it_management_portal/services/task_service.dart';

import 'task_service_test.dart'
    show FakeEmployees, FakeTasks, emp, task, userOf;

TaskDraft draftWith({required bool docs}) => TaskDraft(
      title: 'Fix login',
      description: 'Details',
      taskType: 'Bug Fix',
      assignedEmployeeId: 'EMP-0002',
      priority: 'Normal',
      estimatedHours: 8,
      expectedCompletion: DateTime.utc(2026, 12, 1),
      documentationRequired: docs,
    );

void main() {
  late FakeTasks tasks;
  late FakeEmployees employees;
  late TaskService service;
  late AppUser lead; // EMP-0001, Team Lead
  late AppUser worker; // EMP-0002, assignee of task()
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

  group('request estimate revision', () {
    test('the assignee asks; the original estimate is not touched', () async {
      await service.requestEstimateRevision(
        worker,
        task(status: TaskStatus.inProgress),
        hours: 12,
        reason: ' Scope grew ',
      );
      final f = tasks.updateCalls.single;
      expect(f['ProposedEstimatedHours'], 12);
      expect(f['EstimateRevisionReason'], 'Scope grew');
      expect(f.containsKey('EstimatedHours'), isFalse);
      expect(f.containsKey('RevisedEstimatedHours'), isFalse);
    });

    test('a lead may ask too', () async {
      await service.requestEstimateRevision(
        lead,
        task(status: TaskStatus.accepted),
        hours: 10,
        reason: 'More testing',
      );
      expect(tasks.updateCalls, hasLength(1));
    });

    test('someone else cannot ask', () async {
      final e = await ruleError(() => service.requestEstimateRevision(
            other,
            task(status: TaskStatus.inProgress),
            hours: 12,
            reason: 'x',
          ));
      expect(e.message, contains('assigned person'));
      expect(tasks.updateCalls, isEmpty);
    });

    test('not allowed on a New or Pending Review task', () async {
      for (final s in [TaskStatus.newTask, TaskStatus.pendingReview]) {
        await ruleError(() => service.requestEstimateRevision(
              worker,
              task(status: s),
              hours: 12,
              reason: 'x',
            ));
      }
      expect(tasks.updateCalls, isEmpty);
    });

    test('only one revision can wait at a time', () async {
      final e = await ruleError(() => service.requestEstimateRevision(
            worker,
            task(status: TaskStatus.inProgress, proposed: 12),
            hours: 14,
            reason: 'x',
          ));
      expect(e.message, contains('already waiting'));
    });

    test('hours and reason are checked', () async {
      final t = task(status: TaskStatus.inProgress);
      for (final hours in <double?>[null, 0, -1, 1001, 8]) {
        await ruleError(() => service.requestEstimateRevision(
              worker,
              t,
              hours: hours,
              reason: 'x',
            ));
      }
      await ruleError(() => service.requestEstimateRevision(
            worker,
            t,
            hours: 12,
            reason: '   ',
          ));
      expect(tasks.updateCalls, isEmpty);
    });

    test('the new estimate is compared with the approved revision', () async {
      await ruleError(() => service.requestEstimateRevision(
            worker,
            task(status: TaskStatus.inProgress, revised: 12),
            hours: 12,
            reason: 'x',
          ));
    });
  });

  group('decide on a revision', () {
    test('a lead approves: revised set, proposal cleared, audit filled',
        () async {
      await service.approveEstimateRevision(
        lead,
        task(status: TaskStatus.inProgress, proposed: 12),
      );
      final f = tasks.updateCalls.single;
      expect(f['RevisedEstimatedHours'], 12);
      expect(f['ProposedEstimatedHours'], isNull);
      expect(f.containsKey('ProposedEstimatedHours'), isTrue);
      expect(f['EstimateApprovedBy'], 'EMP-0001');
      expect(f['EstimateApprovedAtUTC'], '2026-11-03T02:00:00.000Z');
      expect(f.containsKey('EstimatedHours'), isFalse);
    });

    test('the assignee cannot approve', () async {
      await ruleError(() => service.approveEstimateRevision(
            worker,
            task(status: TaskStatus.inProgress, proposed: 12),
          ));
      expect(tasks.updateCalls, isEmpty);
    });

    test('nothing to approve', () async {
      final e = await ruleError(() => service.approveEstimateRevision(
            lead,
            task(status: TaskStatus.inProgress),
          ));
      expect(e.message, contains('no revision'));
    });

    test('refusing needs a reason and keeps the estimate in force', () async {
      final t = task(status: TaskStatus.inProgress, proposed: 12, revised: 10);
      await ruleError(
        () => service.rejectEstimateRevision(lead, t, reason: ' '),
      );
      await service.rejectEstimateRevision(lead, t, reason: 'Too high');
      final f = tasks.updateCalls.single;
      expect(f['ProposedEstimatedHours'], isNull);
      expect(f['EstimateRevisionReason'], 'Rejected: Too high');
      expect(f.containsKey('RevisedEstimatedHours'), isFalse);
      expect(t.effectiveEstimateHours, 10);
    });
  });

  group('documentation', () {
    test('the assignee submits with a note', () async {
      await service.submitDocumentation(
        worker,
        task(status: TaskStatus.inProgress, docs: DocumentationStatus.pending),
        note: ' Handover folder ',
      );
      final f = tasks.updateCalls.single;
      expect(f['DocumentationStatus'], 'Submitted');
      expect(f['DocumentationRemarks'], 'Submitted by EMP-0002: Handover folder');
    });

    test('a rejected document can be submitted again', () async {
      await service.submitDocumentation(
        worker,
        task(status: TaskStatus.inProgress, docs: DocumentationStatus.rejected),
        note: 'Fixed',
      );
      expect(tasks.updateCalls, hasLength(1));
    });

    test('a note is required and others cannot submit', () async {
      final t =
          task(status: TaskStatus.inProgress, docs: DocumentationStatus.pending);
      await ruleError(
        () => service.submitDocumentation(worker, t, note: ' '),
      );
      await ruleError(
        () => service.submitDocumentation(lead, t, note: 'x'),
      );
      expect(tasks.updateCalls, isEmpty);
    });

    test('cannot submit when documentation is not required', () async {
      await ruleError(() => service.submitDocumentation(
            worker,
            task(status: TaskStatus.inProgress),
            note: 'x',
          ));
    });

    test('a lead accepts submitted documentation', () async {
      await service.reviewDocumentation(
        lead,
        task(
          status: TaskStatus.pendingReview,
          docs: DocumentationStatus.submitted,
        ),
        accept: true,
      );
      final f = tasks.updateCalls.single;
      expect(f['DocumentationStatus'], 'Reviewed');
      expect(f['DocumentationRemarks'], 'Reviewed by EMP-0001');
    });

    test('sending back needs a reason', () async {
      final t = task(
        status: TaskStatus.pendingReview,
        docs: DocumentationStatus.submitted,
      );
      await ruleError(
        () => service.reviewDocumentation(lead, t, accept: false),
      );
      await service.reviewDocumentation(
        lead,
        t,
        accept: false,
        remarks: 'Missing install steps',
      );
      final f = tasks.updateCalls.single;
      expect(f['DocumentationStatus'], 'Rejected');
      expect(f['DocumentationRemarks'],
          'Rejected by EMP-0001: Missing install steps');
    });

    test('the assignee cannot review; only submitted documents are reviewed',
        () async {
      await ruleError(() => service.reviewDocumentation(
            worker,
            task(
              status: TaskStatus.pendingReview,
              docs: DocumentationStatus.submitted,
            ),
            accept: true,
          ));
      await ruleError(() => service.reviewDocumentation(
            lead,
            task(
              status: TaskStatus.pendingReview,
              docs: DocumentationStatus.pending,
            ),
            accept: true,
          ));
      expect(tasks.updateCalls, isEmpty);
    });

    test('a lead waives with a reason and approval then works', () async {
      final t =
          task(status: TaskStatus.pendingReview, docs: DocumentationStatus.pending);
      await ruleError(() => service.waiveDocumentation(lead, t, reason: ''));
      await service.waiveDocumentation(lead, t, reason: 'Small fix');
      final f = tasks.updateCalls.single;
      expect(f['DocumentationStatus'], 'Not Required');
      expect(f['DocumentationRemarks'], 'Waived by EMP-0001: Small fix');
    });

    test('the assignee cannot waive', () async {
      await ruleError(() => service.waiveDocumentation(
            worker,
            task(
              status: TaskStatus.inProgress,
              docs: DocumentationStatus.pending,
            ),
            reason: 'x',
          ));
    });

    test('final approval is still blocked until docs are done', () async {
      final e = await ruleError(() => service.changeStatus(
            lead,
            task(
              status: TaskStatus.pendingReview,
              docs: DocumentationStatus.pending,
              completionRemarks: 'Done',
            ),
            TaskStatus.completed,
          ));
      expect(e.message, contains('documentation'));
    });

    test('a waived task can be approved', () async {
      await service.changeStatus(
        lead,
        task(
          status: TaskStatus.pendingReview,
          docs: DocumentationStatus.notRequired,
          docRequired: true,
          completionRemarks: 'Done',
        ),
        TaskStatus.completed,
      );
      expect(tasks.updateCalls.single['Status'], 'Completed');
    });
  });

  group('editing the documentation switch', () {
    test('turning it on resets the status to Pending', () async {
      await service.update(
        lead,
        task(status: TaskStatus.accepted),
        draftWith(docs: true),
      );
      expect(tasks.updateCalls.single['DocumentationStatus'], 'Pending');
    });

    test('turning it off sets Not Required', () async {
      await service.update(
        lead,
        task(status: TaskStatus.accepted, docs: DocumentationStatus.pending),
        draftWith(docs: false),
      );
      expect(tasks.updateCalls.single['DocumentationStatus'], 'Not Required');
    });

    test('leaving it alone keeps a waiver', () async {
      await service.update(
        lead,
        task(
          status: TaskStatus.accepted,
          docs: DocumentationStatus.notRequired,
          docRequired: true,
        ),
        draftWith(docs: true),
      );
      expect(
        tasks.updateCalls.single.containsKey('DocumentationStatus'),
        isFalse,
      );
    });
  });

  group('capabilities', () {
    test('nothing is open on final tasks', () {
      final t = task(
        status: TaskStatus.completed,
        docs: DocumentationStatus.submitted,
        proposed: 12,
      );
      expect(TaskCapabilities.of(lead, t).hasAny, isFalse);
      expect(TaskCapabilities.of(worker, t).hasAny, isFalse);
    });

    test('an unrelated employee has nothing to do', () {
      final t = task(
        status: TaskStatus.inProgress,
        docs: DocumentationStatus.pending,
        proposed: 12,
      );
      expect(TaskCapabilities.of(other, t).hasAny, isFalse);
    });
  });
}
