import '../../models/task_item.dart';
import '../../models/time_log.dart';

enum TimerLoadStatus { loading, ready, failed }

/// What the Time Tracker screen shows.
class TimeTrackerState {
  const TimeTrackerState({
    this.status = TimerLoadStatus.loading,
    this.active,
    this.logs = const [],
    this.totalMinutes = 0,
    this.myTasks = const [],
    this.pausedTaskCode,
    this.busy = false,
    this.errorMessage,
  });

  final TimerLoadStatus status;

  /// The running timer, read from SharePoint. Null when none runs.
  final TimeLog? active;

  /// Today's finished segments, newest first.
  final List<TimeLog> logs;

  /// Minutes worked today, not counting the running segment.
  final double totalMinutes;

  /// My tasks that are In Progress.
  final List<TaskItem> myTasks;

  /// The task last paused in this session. Only a convenience for the Resume
  /// button. Not stored anywhere, and lost when the app closes.
  final String? pausedTaskCode;

  /// True while a start, pause or end is being saved.
  final bool busy;
  final String? errorMessage;

  TimeTrackerState copyWith({
    TimerLoadStatus? status,
    TimeLog? active,
    bool clearActive = false,
    List<TimeLog>? logs,
    double? totalMinutes,
    List<TaskItem>? myTasks,
    String? pausedTaskCode,
    bool clearPaused = false,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
  }) =>
      TimeTrackerState(
        status: status ?? this.status,
        active: clearActive ? null : (active ?? this.active),
        logs: logs ?? this.logs,
        totalMinutes: totalMinutes ?? this.totalMinutes,
        myTasks: myTasks ?? this.myTasks,
        pausedTaskCode: clearPaused ? null : (pausedTaskCode ?? this.pausedTaskCode),
        busy: busy ?? this.busy,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}
