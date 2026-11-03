import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/core/utilities/malaysia_time.dart';
import 'package:it_management_portal/data/api/graph_client.dart';
import 'package:it_management_portal/data/repositories/time_log_repository.dart';
import 'package:it_management_portal/models/app_user.dart';
import 'package:it_management_portal/models/task_enums.dart';
import 'package:it_management_portal/models/time_log.dart';
import 'package:it_management_portal/services/time_log_codes.dart';
import 'package:it_management_portal/services/time_tracking_service.dart';

import 'task_service_test.dart' show emp, task, userOf;

TimeLog log({
  String employee = 'EMP-0002',
  String code = 'TL-2026-000001',
  String taskCode = 'TASK-2026-00001',
  DateTime? start,
  DateTime? end,
  double? minutes,
  TimerStatus status = TimerStatus.active,
  bool deleted = false,
}) =>
    TimeLog(
      itemId: '1',
      etag: '"1"',
      timeLogCode: code,
      employeeId: employee,
      taskCode: taskCode,
      startUtc: start ?? DateTime.utc(2026, 11, 3, 1),
      endUtc: end,
      durationMinutes: minutes,
      status: status,
      activeTimerKey:
          status == TimerStatus.active ? 'ACTIVE|$employee' : '',
      isDeleted: deleted,
    );

class FakeLogs implements TimeLogDirectory {
  TimeLog? active;
  String? highest;
  List<TimeLog> since = [];
  final createCalls = <Map<String, Object?>>[];
  final updateCalls = <Map<String, Object?>>[];
  final createErrors = <GraphException>[];
  GraphException? updateError;
  DateTime? lastSince;

  @override
  Future<TimeLog?> findActive(String employeeId) async =>
      active?.employeeId == employeeId ? active : null;

  @override
  Future<List<TimeLog>> listSince(String employeeId, DateTime sinceUtc) async {
    lastSince = sinceUtc;
    return since;
  }

  @override
  Future<String?> highestCode() async => highest;

  @override
  Future<TimeLog> create(Map<String, Object?> fields) async {
    createCalls.add(fields);
    if (createErrors.isNotEmpty) throw createErrors.removeAt(0);
    return log();
  }

  @override
  Future<TimeLog> update({
    required TimeLog current,
    required Map<String, Object?> fields,
  }) async {
    updateCalls.add(fields);
    if (updateError != null) throw updateError!;
    return current;
  }
}

void main() {
  late FakeLogs logs;
  late TimeTrackingService service;
  late AppUser worker; // EMP-0002
  late AppUser other; // EMP-0003
  var now = DateTime.utc(2026, 11, 3, 3); // 11:00 Malaysia

  setUp(() {
    now = DateTime.utc(2026, 11, 3, 3);
    logs = FakeLogs();
    worker = userOf(emp('2'));
    other = userOf(emp('3'));
    service = TimeTrackingService(logs, clock: () => now);
  });

  Future<TimeRuleException> ruleError(Future<Object?> Function() run) async {
    try {
      await run();
    } on TimeRuleException catch (e) {
      return e;
    }
    fail('Expected a TimeRuleException');
  }

  GraphException duplicate() =>
      GraphException(statusCode: 409, userMessage: 'duplicate');

  group('start', () {
    test('creates an Active row with the unique key', () async {
      await service.start(worker, task(status: TaskStatus.inProgress));
      final f = logs.createCalls.single;
      expect(f['TimeLogCode'], 'TL-2026-000001');
      expect(f['EmployeeID'], 'EMP-0002');
      expect(f['TaskCode'], 'TASK-2026-00001');
      expect(f['StartTimeUTC'], '2026-11-03T03:00:00.000Z');
      expect(f['TimerStatus'], 'Active');
      expect(f['ActiveTimerKey'], 'ACTIVE|EMP-0002');
      expect(f['IsDeleted'], false);
    });

    test('the code follows the highest one', () async {
      logs.highest = 'TL-2026-000041';
      await service.start(worker, task(status: TaskStatus.inProgress));
      expect(logs.createCalls.single['TimeLogCode'], 'TL-2026-000042');
    });

    test('only on my own task', () async {
      final e = await ruleError(
        () => service.start(other, task(status: TaskStatus.inProgress)),
      );
      expect(e.message, contains('your own'));
      expect(logs.createCalls, isEmpty);
    });

    test('only when the task is In Progress', () async {
      for (final s in [
        TaskStatus.newTask,
        TaskStatus.accepted,
        TaskStatus.onHold,
        TaskStatus.pendingReview,
        TaskStatus.completed,
      ]) {
        await ruleError(() => service.start(worker, task(status: s)));
      }
      expect(logs.createCalls, isEmpty);
    });

    test('refused while another timer runs', () async {
      logs.active = log();
      final e = await ruleError(
        () => service.start(worker, task(status: TaskStatus.inProgress)),
      );
      expect(e.message, contains('already have a timer'));
      expect(logs.createCalls, isEmpty);
    });

    test('after a duplicate key the service reports the running timer',
        () async {
      final racing = _RacingLogs(log());
      final svc = TimeTrackingService(racing, clock: () => now);
      final e = await ruleError(
        () => svc.start(worker, task(status: TaskStatus.inProgress)),
      );
      expect(e.message, contains('already have a timer'));
      expect(racing.createCalls, hasLength(1));
    });

    test('a duplicate code is retried, up to 3 times', () async {
      logs.createErrors.addAll([duplicate(), duplicate()]);
      await service.start(worker, task(status: TaskStatus.inProgress));
      expect(logs.createCalls, hasLength(3));
    });

    test('gives up after 3 duplicates', () async {
      logs.createErrors.addAll([duplicate(), duplicate(), duplicate()]);
      final e = await ruleError(
        () => service.start(worker, task(status: TaskStatus.inProgress)),
      );
      expect(e.message, contains('free code'));
      expect(logs.createCalls, hasLength(3));
    });

    test('other errors are not retried', () async {
      logs.createErrors.add(
        GraphException(statusCode: 500, userMessage: 'server'),
      );
      await expectLater(
        service.start(worker, task(status: TaskStatus.inProgress)),
        throwsA(isA<GraphException>()),
      );
      expect(logs.createCalls, hasLength(1));
    });

    test('a bad existing code stops the start', () async {
      logs.highest = 'oops';
      await ruleError(
        () => service.start(worker, task(status: TaskStatus.inProgress)),
      );
      expect(logs.createCalls, isEmpty);
    });
  });

  group('stop', () {
    test('ends the segment, clears the key and stores the minutes', () async {
      now = DateTime.utc(2026, 11, 3, 2, 30, 30); // 90.5 minutes after 01:00
      await service.stop(worker, log(), workResult: ' Fixed it ');
      final f = logs.updateCalls.single;
      expect(f['EndTimeUTC'], '2026-11-03T02:30:30.000Z');
      expect(f['DurationMinutes'], 90.5);
      expect(f['TimerStatus'], 'Completed');
      expect(f.containsKey('ActiveTimerKey'), isTrue);
      expect(f['ActiveTimerKey'], isNull);
      expect(f['WorkResult'], 'Fixed it');
    });

    test('pause needs no result and stores none', () async {
      await service.stop(worker, log());
      expect(logs.updateCalls.single.containsKey('WorkResult'), isFalse);
    });

    test('end job needs a result', () async {
      await ruleError(
        () => service.stop(worker, log(), requireResult: true, workResult: ' '),
      );
      expect(logs.updateCalls, isEmpty);
    });

    test("cannot stop another person's timer", () async {
      final e = await ruleError(() => service.stop(other, log()));
      expect(e.message, contains('another person'));
      expect(logs.updateCalls, isEmpty);
    });

    test('cannot stop a timer that already ended', () async {
      await ruleError(
        () => service.stop(
          worker,
          log(status: TimerStatus.completed, minutes: 5, end: now),
        ),
      );
    });

    test('a clock earlier than the start is refused', () async {
      now = DateTime.utc(2026, 11, 3, 0, 59);
      final e = await ruleError(() => service.stop(worker, log()));
      expect(e.message, contains('clock'));
      expect(logs.updateCalls, isEmpty);
    });

    test('a stale ETag gives a clear message', () async {
      logs.updateError =
          GraphException(statusCode: 412, userMessage: 'precondition');
      final e = await ruleError(() => service.stop(worker, log()));
      expect(e.message, contains('somewhere else'));
    });
  });

  group('today', () {
    test('asks from the start of the Malaysia day', () async {
      await service.today(worker);
      // 2026-11-03 00:00 Malaysia = 2026-11-02 16:00 UTC
      expect(logs.lastSince, DateTime.utc(2026, 11, 2, 16));
    });

    test('totals finished and running segments, skips deleted', () async {
      logs.since = [
        log(
          status: TimerStatus.active,
          start: DateTime.utc(2026, 11, 3, 2, 30), // 30 minutes before now
        ),
        log(
          code: 'b',
          status: TimerStatus.completed,
          start: DateTime.utc(2026, 11, 3, 0),
          end: DateTime.utc(2026, 11, 3, 1),
          minutes: 60,
        ),
        log(
          code: 'c',
          status: TimerStatus.completed,
          minutes: 500,
          deleted: true,
        ),
      ];
      final day = await service.today(worker);
      expect(day.logs, hasLength(2));
      expect(day.totalMinutes, 90);
    });
  });

  group('codes and time helpers', () {
    test('TimeLogCodes', () {
      expect(TimeLogCodes.next(null, 2026), 'TL-2026-000001');
      expect(TimeLogCodes.next('TL-2026-000009', 2026), 'TL-2026-000010');
      expect(TimeLogCodes.next('TL-2025-000300', 2026), 'TL-2026-000001');
      expect(TimeLogCodes.next('TL-2027-000001', 2026), isNull);
      expect(TimeLogCodes.next('TASK-2026-00001', 2026), isNull);
    });

    test('malaysiaDayStartUtc around midnight', () {
      // 23:59 Malaysia on 3 Nov is 15:59 UTC on 3 Nov.
      expect(
        malaysiaDayStartUtc(DateTime.utc(2026, 11, 3, 15, 59)),
        DateTime.utc(2026, 11, 2, 16),
      );
      // 00:00 Malaysia on 4 Nov is 16:00 UTC on 3 Nov.
      expect(
        malaysiaDayStartUtc(DateTime.utc(2026, 11, 3, 16)),
        DateTime.utc(2026, 11, 3, 16),
      );
    });
  });
}

/// Fails the first create with a duplicate and shows a running timer only
/// after that, like a timer started on another PC a moment earlier.
class _RacingLogs extends FakeLogs {
  _RacingLogs(this._running) {
    createErrors.add(GraphException(statusCode: 409, userMessage: 'duplicate'));
  }

  final TimeLog _running;

  @override
  Future<TimeLog?> findActive(String employeeId) async =>
      createCalls.isEmpty ? null : _running;
}
