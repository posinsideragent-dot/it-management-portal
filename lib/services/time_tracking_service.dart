import '../core/configuration/app_config.dart';
import '../core/errors/rule_violation.dart';
import '../core/utilities/malaysia_time.dart';
import '../data/api/graph_client.dart';
import '../data/repositories/time_log_repository.dart';
import '../models/app_user.dart';
import '../models/task_enums.dart';
import '../models/task_item.dart';
import '../models/time_log.dart';
import 'time_log_codes.dart';

/// A time tracking rule was broken. [message] is safe to show to the user.
class TimeRuleException implements RuleViolation {
  TimeRuleException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}

/// Today's logs and the total worked.
class DaySummary {
  const DaySummary({required this.logs, required this.totalMinutes});

  /// Newest first. Logically deleted rows are left out.
  final List<TimeLog> logs;
  final double totalMinutes;
}

/// Business rules for the Time Tracker (step 1: start, pause, resume, end,
/// recovery). Manual correction comes in step 2.
///
/// A timer is one IT_TimeLogs row per work segment. Pause and End both end
/// the running segment. Resume starts a new segment. The only source of truth
/// for a running timer is the Active row in SharePoint: the elapsed time is
/// always worked out from its StartTimeUTC, never from a counter in memory.
///
/// Times come from this PC's clock. They are not tamper-proof.
class TimeTrackingService {
  TimeTrackingService(this._logs, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final TimeLogDirectory _logs;
  final DateTime Function() _now;

  static const _maxCreateAttempts = 3;

  /// The running timer of [actor], read from SharePoint. Null when none.
  Future<TimeLog?> activeTimer(AppUser actor) =>
      _logs.findActive(actor.employee.employeeId);

  /// Today's logs (Malaysia day) and the total worked so far.
  Future<DaySummary> today(AppUser actor) async {
    final now = _now().toUtc();
    final rows = await _logs.listSince(
      actor.employee.employeeId,
      malaysiaDayStartUtc(now),
    );
    final visible = rows.where((r) => !r.isDeleted).toList();
    final total = visible.fold<double>(0, (sum, r) => sum + r.minutesAt(now));
    return DaySummary(logs: visible, totalMinutes: total);
  }

  /// Starts (or resumes) work on [task]. One active timer per employee.
  Future<TimeLog> start(
    AppUser actor,
    TaskItem task, {
    String activity = '',
  }) async {
    final employeeId = actor.employee.employeeId;
    if (task.assignedEmployeeId != employeeId) {
      throw TimeRuleException('You can only track time on your own tasks.');
    }
    if (task.status != TaskStatus.inProgress) {
      throw TimeRuleException(
        'Time can be tracked on tasks that are In Progress. '
        'This task is ${task.status.label}. Use the Tasks page to change it.',
      );
    }
    await _refuseIfRunning(employeeId);

    final now = _now().toUtc();
    for (var attempt = 1; attempt <= _maxCreateAttempts; attempt++) {
      final code = TimeLogCodes.next(await _logs.highestCode(), malaysiaYear(now));
      if (code == null) {
        throw TimeRuleException(
          'An existing TimeLogCode has an unexpected format or year. '
          "Ask IT to check the list and this PC's clock.",
        );
      }
      try {
        return await _logs.create({
          SpFields.title: '${task.taskCode} $employeeId',
          SpFields.timeLogCode: code,
          SpFields.employeeId: employeeId,
          SpFields.taskCode: task.taskCode,
          SpFields.startTimeUtc: now.toIso8601String(),
          SpFields.timerStatus: TimerStatus.active.label,
          SpFields.activeTimerKey: TimeLog.activeKeyFor(employeeId),
          if (activity.trim().isNotEmpty)
            SpFields.activityDescription: activity.trim(),
          SpFields.isDeleted: false,
        });
      } on GraphException catch (e) {
        if (!e.isDuplicateValue) rethrow;
        // A duplicate means nothing was created. It is either a timer that
        // started on another PC a moment ago, or a code another person took.
        await _refuseIfRunning(employeeId);
        if (attempt == _maxCreateAttempts) {
          throw TimeRuleException('Could not get a free code. Try again.');
        }
      }
    }
    throw StateError('unreachable');
  }

  /// Ends the running segment of [actor]. [workResult] says what was done.
  /// Pass [requireResult] for End Job. Pause does not need one.
  Future<TimeLog> stop(
    AppUser actor,
    TimeLog running, {
    String workResult = '',
    bool requireResult = false,
  }) async {
    if (running.employeeId != actor.employee.employeeId) {
      throw TimeRuleException("You cannot change another person's time log.");
    }
    if (!running.isActive) {
      throw TimeRuleException('This timer has already ended. Reload the page.');
    }
    final result = workResult.trim();
    if (requireResult && result.isEmpty) {
      throw TimeRuleException('Enter what you did in this session.');
    }
    final now = _now().toUtc();
    if (now.isBefore(running.startUtc)) {
      throw TimeRuleException(
        "This PC's clock is earlier than the start time. "
        'Check the date and time, then try again.',
      );
    }
    final minutes = _roundMinutes(now.difference(running.startUtc));
    try {
      return await _logs.update(
        current: running,
        fields: {
          SpFields.endTimeUtc: now.toIso8601String(),
          SpFields.durationMinutes: minutes,
          SpFields.timerStatus: TimerStatus.completed.label,
          // Clearing the key frees the employee to start another timer.
          SpFields.activeTimerKey: null,
          if (result.isNotEmpty) SpFields.workResult: result,
        },
      );
    } on GraphException catch (e) {
      if (e.isPreconditionFailed) {
        throw TimeRuleException(
          'This timer was changed somewhere else (maybe on another PC). '
          'Reload the page.',
        );
      }
      rethrow;
    }
  }

  Future<void> _refuseIfRunning(String employeeId) async {
    final running = await _logs.findActive(employeeId);
    if (running != null) {
      throw TimeRuleException(
        'You already have a timer running on ${running.taskCode}. '
        'Pause or end it first.',
      );
    }
  }

  /// Minutes to 2 decimals, from whole seconds.
  static double _roundMinutes(Duration d) =>
      (d.inSeconds / 60 * 100).round() / 100;
}
