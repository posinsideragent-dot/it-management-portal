import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/core/utilities/malaysia_time.dart';
import 'package:it_management_portal/data/api/graph_client.dart';
import 'package:it_management_portal/models/task_draft.dart';
import 'package:it_management_portal/models/task_enums.dart';
import 'package:it_management_portal/services/task_access.dart';
import 'package:it_management_portal/services/task_codes.dart';
import 'package:it_management_portal/services/task_validator.dart';
import 'package:it_management_portal/services/task_variance.dart';
import 'package:it_management_portal/services/task_workflow.dart';

TaskDraft draft({
  String title = 'Fix login',
  String description = 'Details',
  String type = 'Bug Fix',
  String assignee = 'EMP-0002',
  String priority = 'Normal',
  double? hours = 4,
  DateTime? due,
  DateTime? start,
}) =>
    TaskDraft(
      title: title,
      description: description,
      taskType: type,
      assignedEmployeeId: assignee,
      priority: priority,
      estimatedHours: hours,
      expectedCompletion: due ?? DateTime.utc(2026, 12, 1),
      plannedStart: start,
      documentationRequired: false,
    );

void main() {
  group('TaskCodes', () {
    test('first code of the year', () {
      expect(TaskCodes.next(null, 2026), 'TASK-2026-00001');
    });
    test('next number in the same year', () {
      expect(TaskCodes.next('TASK-2026-00009', 2026), 'TASK-2026-00010');
    });
    test('the number restarts in a new year', () {
      expect(TaskCodes.next('TASK-2026-00123', 2027), 'TASK-2027-00001');
    });
    test('a later year in the list means a wrong clock', () {
      expect(TaskCodes.next('TASK-2027-00001', 2026), isNull);
    });
    test('a bad format gives null', () {
      expect(TaskCodes.next('T-1', 2026), isNull);
    });
  });

  group('TaskWorkflow', () {
    const assignee = {TaskActor.assignee};
    const lead = {TaskActor.lead};

    TaskStatus? tryMove(TaskStatus from, TaskStatus to, Set<TaskActor> who) =>
        TaskWorkflow.find(from, to, who)?.to;

    test('the normal path works for the right people', () {
      expect(tryMove(TaskStatus.newTask, TaskStatus.accepted, assignee), isNotNull);
      expect(tryMove(TaskStatus.accepted, TaskStatus.inProgress, assignee), isNotNull);
      expect(tryMove(TaskStatus.inProgress, TaskStatus.pendingReview, assignee), isNotNull);
      expect(tryMove(TaskStatus.pendingReview, TaskStatus.completed, lead), isNotNull);
    });

    test('the assignee cannot approve and a lead cannot accept', () {
      expect(tryMove(TaskStatus.pendingReview, TaskStatus.completed, assignee), isNull);
      expect(tryMove(TaskStatus.newTask, TaskStatus.accepted, lead), isNull);
    });

    test('steps cannot be skipped', () {
      expect(tryMove(TaskStatus.newTask, TaskStatus.inProgress, assignee), isNull);
      expect(tryMove(TaskStatus.newTask, TaskStatus.completed, {...assignee, ...lead}), isNull);
      expect(tryMove(TaskStatus.inProgress, TaskStatus.completed, lead), isNull);
    });

    test('Completed and Cancelled are final', () {
      const everyone = {TaskActor.assignee, TaskActor.lead};
      expect(TaskWorkflow.movesFor(TaskStatus.completed, everyone), isEmpty);
      expect(TaskWorkflow.movesFor(TaskStatus.cancelled, everyone), isEmpty);
      expect(TaskStatus.completed.isFinal, isTrue);
    });

    test('hold, cancel, return and submit need a reason', () {
      expect(TaskWorkflow.find(TaskStatus.inProgress, TaskStatus.onHold, assignee)!.needsRemarks, isTrue);
      expect(TaskWorkflow.find(TaskStatus.newTask, TaskStatus.cancelled, lead)!.needsRemarks, isTrue);
      expect(TaskWorkflow.find(TaskStatus.pendingReview, TaskStatus.inProgress, lead)!.needsRemarks, isTrue);
      expect(TaskWorkflow.find(TaskStatus.inProgress, TaskStatus.pendingReview, assignee)!.needsRemarks, isTrue);
      expect(TaskWorkflow.find(TaskStatus.newTask, TaskStatus.accepted, assignee)!.needsRemarks, isFalse);
    });

    test('a task on hold can resume', () {
      expect(tryMove(TaskStatus.onHold, TaskStatus.inProgress, assignee), isNotNull);
    });
  });

  group('TaskValidator', () {
    Map<TaskFormField, String> check(TaskDraft d, {DateTime? now}) =>
        TaskValidator.validate(d, nowUtc: now);

    test('a good draft has no errors', () {
      expect(check(draft()), isEmpty);
    });
    test('required text and choices', () {
      expect(check(draft(title: ' ')), contains(TaskFormField.title));
      expect(check(draft(description: '')), contains(TaskFormField.description));
      expect(check(draft(type: 'Other')), contains(TaskFormField.taskType));
      expect(check(draft(priority: 'Urgent')), contains(TaskFormField.priority));
      expect(check(draft(assignee: '')), contains(TaskFormField.assignee));
    });
    test('estimate must be a positive number up to 1000', () {
      expect(check(draft(hours: null)), contains(TaskFormField.estimate));
      expect(check(draft(hours: 0)), contains(TaskFormField.estimate));
      expect(check(draft(hours: -1)), contains(TaskFormField.estimate));
      expect(check(draft(hours: 1001)), contains(TaskFormField.estimate));
      expect(check(draft(hours: 0.5)), isEmpty);
    });
    test('a past completion date is refused on create', () {
      final errors = check(draft(due: DateTime.utc(2026, 1, 1)), now: DateTime.utc(2026, 11, 3));
      expect(errors, contains(TaskFormField.expectedCompletion));
    });
    test('planned start must not be after completion', () {
      final errors = check(draft(start: DateTime.utc(2027, 1, 1)));
      expect(errors, contains(TaskFormField.plannedStart));
    });
  });

  group('TaskVariance', () {
    test('hours and percent', () {
      final v = TaskVariance.compute(estimatedHours: 8, actualHours: 10);
      expect(v.hours, 2);
      expect(v.percent, 25);
    });
    test('under the estimate is negative', () {
      final v = TaskVariance.compute(estimatedHours: 10, actualHours: 5);
      expect(v.hours, -5);
      expect(v.percent, -50);
    });
    test('no percent when the estimate is zero', () {
      final v = TaskVariance.compute(estimatedHours: 0, actualHours: 3);
      expect(v.hours, 3);
      expect(v.percent, isNull);
    });
  });

  group('Malaysia time helpers', () {
    test('wall clock Malaysia to UTC', () {
      expect(malaysiaWallClockToUtc(2026, 11, 3, 17, 0), DateTime.utc(2026, 11, 3, 9));
      expect(malaysiaWallClockToUtc(2026, 11, 3, 5, 0), DateTime.utc(2026, 11, 2, 21));
    });
    test('Malaysia year changes before UTC year', () {
      expect(malaysiaYear(DateTime.utc(2026, 12, 31, 20)), 2027);
      expect(malaysiaYear(DateTime.utc(2026, 12, 31, 10)), 2026);
    });
  });

  group('GraphException.isDuplicateValue', () {
    test('409 and unique-value 400 count', () {
      expect(GraphException(statusCode: 409, userMessage: 'x').isDuplicateValue, isTrue);
      expect(
        GraphException(statusCode: 400, userMessage: 'Value must be unique').isDuplicateValue,
        isTrue,
      );
    });
    test('other errors do not', () {
      expect(GraphException(statusCode: 500, userMessage: 'unique').isDuplicateValue, isFalse);
      expect(GraphException(statusCode: 400, userMessage: 'bad').isDuplicateValue, isFalse);
    });
  });

  group('TaskDraft fields', () {
    test('create fields start as New with 0 progress', () {
      final f = draft().toCreateFields(taskCode: 'TASK-2026-00001', createdByEmployeeId: 'EMP-0001');
      expect(f['Status'], 'New');
      expect(f['Progress'], 0);
      expect(f['TaskCode'], 'TASK-2026-00001');
      expect(f['DocumentationStatus'], 'Not Required');
    });
    test('update fields skip the estimate once it is locked', () {
      expect(draft().toUpdateFields(includeEstimate: false).containsKey('EstimatedHours'), isFalse);
      expect(draft().toUpdateFields(includeEstimate: true)['EstimatedHours'], 4);
    });
  });
}
