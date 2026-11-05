import '../core/utilities/office_hours.dart';
import '../models/task_enums.dart';
import '../models/task_item.dart';

/// Hours used on a task and how they compare with the original estimate.
class TaskHoursSummary {
  const TaskHoursSummary({
    required this.usedMinutes,
    required this.varianceMinutes,
    required this.stillRunning,
  });

  final double usedMinutes;

  /// Used minus the original estimate. Positive means over the estimate.
  final double varianceMinutes;

  /// True while the task is In Progress, so the hours are "so far".
  final bool stillRunning;

  /// Variance as a share of the original estimate, such as 0.25 for +25%.
  double variancePercentOf(double originalHours) =>
      originalHours <= 0 ? 0 : varianceMinutes / (originalHours * 60);
}

/// Works out hours used from the task's own dates. No timer is needed.
///
/// Hours used = office hours from the first start to the last submit for
/// review (or to now while In Progress), minus the held time: On Hold and
/// waiting in review. The variance is always against the original estimate.
class TaskHours {
  const TaskHours._();

  /// Null when the dates needed are not recorded (for example, tasks made
  /// before these dates were saved, or a task that has not started).
  static TaskHoursSummary? compute(
    TaskItem task,
    DateTime nowUtc, {
    OfficeHours office = OfficeHours.standard,
  }) {
    final start = task.actualStart;
    if (start == null) return null;

    final DateTime? end;
    var running = false;
    switch (task.status) {
      case TaskStatus.inProgress:
        end = nowUtc;
        running = true;
      case TaskStatus.onHold:
        end = task.holdStartedAtUtc;
      case TaskStatus.pendingReview:
      case TaskStatus.completed:
        end = task.submittedAtUtc;
      case TaskStatus.newTask:
      case TaskStatus.accepted:
      case TaskStatus.cancelled:
        end = null;
    }
    if (end == null) return null;

    final gross = office.minutesBetween(start, end);
    final used = (gross - task.heldMinutes).clamp(0, double.infinity).toDouble();
    return TaskHoursSummary(
      usedMinutes: used,
      varianceMinutes: used - task.estimatedHours * 60,
      stillRunning: running,
    );
  }
}
