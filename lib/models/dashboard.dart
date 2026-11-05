import 'task_item.dart';

/// Where a dashboard alert leads when it is clicked.
enum AlertTarget { tasks, issues, dailyReports }

/// Who the alert is for: work to review (Team Lead, Management, Admin) or
/// the person's own to-do.
enum AlertGroup {
  toReview('To review'),
  yourActions('Your actions');

  const AlertGroup(this.label);
  final String label;
}

/// One thing that needs the signed-in person to act.
class DashboardAlert {
  const DashboardAlert({
    required this.group,
    required this.target,
    required this.title,
    required this.action,
    this.employeeId = '',
  });

  final AlertGroup group;
  final AlertTarget target;

  /// For example `TASK-2026-00001: Fix login`.
  final String title;

  /// What to do, in plain words.
  final String action;

  /// The person the item belongs to, shown by name. Empty when not needed.
  final String employeeId;
}

/// A task in one of the four task groups, with its days to the due date.
class DashboardTask {
  const DashboardTask({required this.task, required this.daysToDue});

  final TaskItem task;

  /// Malaysia calendar days until the due date. 0 is today. Negative is late.
  final int daysToDue;

  bool get isOverdue => daysToDue < 0;
}

/// What the dashboard shows.
class DashboardData {
  const DashboardData({
    required this.viewAll,
    required this.pendingAccept,
    required this.startWork,
    required this.almostDue,
    required this.due,
    required this.alerts,
    required this.loadedAtUtc,
    this.truncated = false,
  });

  /// True for the Team Lead, Management and Admin view (all tasks).
  final bool viewAll;

  /// Status New: waiting for the assignee to accept.
  final List<DashboardTask> pendingAccept;

  /// Status Accepted: accepted, work not started yet.
  final List<DashboardTask> startWork;

  /// Not finished, due in 1 to 3 days.
  final List<DashboardTask> almostDue;

  /// Not finished, due today or already late.
  final List<DashboardTask> due;

  final List<DashboardAlert> alerts;
  final DateTime loadedAtUtc;

  /// True when a list was too long to load fully. Counts may be low.
  final bool truncated;
}
