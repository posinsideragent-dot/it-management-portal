import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/core/utilities/office_hours.dart';
import 'package:it_management_portal/models/task_enums.dart';
import 'package:it_management_portal/services/task_hours.dart';
import 'package:it_management_portal/services/task_service.dart';

import 'task_service_test.dart'
    show FakeEmployees, FakeTasks, emp, task, userOf;

// Malaysia is UTC+8. 2026-11-02 is a Monday, 2026-11-06 a Friday.
DateTime myt(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute).subtract(const Duration(hours: 8));

void main() {
  group('OfficeHours', () {
    const office = OfficeHours.standard;

    test('inside one office day', () {
      expect(office.minutesBetween(myt(2, 10), myt(2, 12, 30)), 150);
    });

    test('a full office day is 9 hours', () {
      expect(office.minutesBetween(myt(2, 9), myt(2, 18)), 540);
    });

    test('before and after office hours do not count', () {
      expect(office.minutesBetween(myt(2, 6), myt(2, 9)), 0);
      expect(office.minutesBetween(myt(2, 18), myt(2, 23)), 0);
      expect(office.minutesBetween(myt(2, 7), myt(2, 10)), 60);
    });

    test('weekends do not count', () {
      // Friday 17:00 to Monday 10:00 is 1 h on Friday and 1 h on Monday.
      expect(office.minutesBetween(myt(6, 17), myt(9, 10)), 120);
      expect(office.minutesBetween(myt(7, 9), myt(8, 18)), 0);
    });

    test('several days', () {
      expect(office.minutesBetween(myt(2, 9), myt(4, 18)), 3 * 540);
    });

    test('an end before the start is zero', () {
      expect(office.minutesBetween(myt(2, 12), myt(2, 10)), 0);
      expect(office.minutesBetween(myt(2, 12), myt(2, 12)), 0);
    });
  });

  group('TaskHours', () {
    test('In Progress counts up to now and compares with the original', () {
      final r = TaskHours.compute(
        task(
          status: TaskStatus.inProgress,
          actualStart: myt(2, 9).toUtc(),
          estimate: 8,
        ),
        myt(2, 13),
      )!;
      expect(r.usedMinutes, 240);
      expect(r.varianceMinutes, -240);
      expect(r.stillRunning, isTrue);
      expect(r.variancePercentOf(8), -0.5);
    });

    test('held time is taken out', () {
      final r = TaskHours.compute(
        task(
          status: TaskStatus.inProgress,
          actualStart: myt(2, 9).toUtc(),
          estimate: 2,
          held: 60,
        ),
        myt(2, 13),
      )!;
      expect(r.usedMinutes, 180);
      expect(r.varianceMinutes, 60); // 3 h used against 2 h
    });

    test('Pending Review and Completed stop at the submit time', () {
      for (final s in [TaskStatus.pendingReview, TaskStatus.completed]) {
        final r = TaskHours.compute(
          task(
            status: s,
            actualStart: myt(2, 9).toUtc(),
            submittedAt: myt(2, 11).toUtc(),
            estimate: 1,
          ),
          myt(5, 15), // days later: must not matter
        )!;
        expect(r.usedMinutes, 120);
        expect(r.varianceMinutes, 60);
        expect(r.stillRunning, isFalse);
      }
    });

    test('On Hold stops at the moment it was held', () {
      final r = TaskHours.compute(
        task(
          status: TaskStatus.onHold,
          actualStart: myt(2, 9).toUtc(),
          holdStartedAt: myt(2, 10).toUtc(),
        ),
        myt(4, 10),
      )!;
      expect(r.usedMinutes, 60);
    });

    test('nothing to show when the dates are missing', () {
      final started = myt(2, 9).toUtc();
      expect(TaskHours.compute(task(status: TaskStatus.accepted), myt(2, 10)), isNull);
      expect(
        TaskHours.compute(
          task(status: TaskStatus.pendingReview, actualStart: started),
          myt(2, 10),
        ),
        isNull,
      );
      expect(
        TaskHours.compute(
          task(status: TaskStatus.cancelled, actualStart: started),
          myt(2, 10),
        ),
        isNull,
      );
    });

    test('hours never go below zero', () {
      final r = TaskHours.compute(
        task(
          status: TaskStatus.inProgress,
          actualStart: myt(2, 9).toUtc(),
          held: 9999,
        ),
        myt(2, 10),
      )!;
      expect(r.usedMinutes, 0);
    });
  });

  group('status moves save the dates', () {
    late FakeTasks tasks;
    late TaskService service;
    late FakeEmployees employees;
    var now = DateTime.utc(2026, 11, 3, 2);

    setUp(() {
      now = DateTime.utc(2026, 11, 3, 2);
      tasks = FakeTasks();
      employees = FakeEmployees()
        ..rows.addAll([emp('1', role: 'TeamLead'), emp('2')]);
      service = TaskService(tasks, employees, clock: () => now);
    });

    final lead = userOf(emp('1', role: 'TeamLead'));
    final worker = userOf(emp('2'));

    test('accept saves AcceptedAtUTC', () async {
      await service.changeStatus(worker, task(), TaskStatus.accepted);
      expect(
        tasks.updateCalls.single['AcceptedAtUTC'],
        '2026-11-03T02:00:00.000Z',
      );
    });

    test('submit for review saves SubmittedAtUTC', () async {
      await service.changeStatus(
        worker,
        task(status: TaskStatus.inProgress),
        TaskStatus.pendingReview,
        remarks: 'Done',
      );
      expect(
        tasks.updateCalls.single['SubmittedAtUTC'],
        '2026-11-03T02:00:00.000Z',
      );
    });

    test('putting a started task on hold saves HoldStartedAtUTC', () async {
      await service.changeStatus(
        worker,
        task(status: TaskStatus.inProgress, actualStart: myt(3, 9).toUtc()),
        TaskStatus.onHold,
        remarks: 'Waiting',
      );
      expect(
        tasks.updateCalls.single['HoldStartedAtUTC'],
        '2026-11-03T02:00:00.000Z',
      );
    });

    test('holding a task that never started saves no hold start', () async {
      await service.changeStatus(
        worker,
        task(status: TaskStatus.accepted),
        TaskStatus.onHold,
        remarks: 'Waiting',
      );
      expect(tasks.updateCalls.single.containsKey('HoldStartedAtUTC'), isFalse);
    });

    test('resume adds the office time on hold and clears the hold', () async {
      now = myt(3, 14).toUtc(); // 14:00 Malaysia
      await service.changeStatus(
        worker,
        task(
          status: TaskStatus.onHold,
          actualStart: myt(3, 9).toUtc(),
          holdStartedAt: myt(3, 10).toUtc(),
          held: 30,
        ),
        TaskStatus.inProgress,
      );
      final f = tasks.updateCalls.single;
      expect(f['HeldMinutes'], 270); // 30 + 4 h
      expect(f.containsKey('HoldStartedAtUTC'), isTrue);
      expect(f['HoldStartedAtUTC'], isNull);
    });

    test('return for rework counts the review wait as held', () async {
      now = myt(3, 15).toUtc();
      await service.changeStatus(
        lead,
        task(
          status: TaskStatus.pendingReview,
          actualStart: myt(3, 9).toUtc(),
          submittedAt: myt(3, 13, 30).toUtc(),
          held: 30,
        ),
        TaskStatus.inProgress,
        remarks: 'Fix it',
      );
      final f = tasks.updateCalls.single;
      expect(f['HeldMinutes'], 120); // 30 + 1 h 30
      expect(f.containsKey('SubmittedAtUTC'), isTrue);
      expect(f['SubmittedAtUTC'], isNull);
    });

    test('the first start still sets ActualStart only once', () async {
      await service.changeStatus(
        worker,
        task(status: TaskStatus.accepted),
        TaskStatus.inProgress,
      );
      expect(tasks.updateCalls.single['ActualStart'], isNotNull);
      tasks.updateCalls.clear();
      await service.changeStatus(
        worker,
        task(status: TaskStatus.onHold, actualStart: myt(2, 9).toUtc()),
        TaskStatus.inProgress,
      );
      expect(tasks.updateCalls.single.containsKey('ActualStart'), isFalse);
    });
  });
}
