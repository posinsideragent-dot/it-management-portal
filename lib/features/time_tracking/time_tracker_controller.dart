import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/rule_violation.dart';
import '../../data/api/graph_client.dart';
import '../../models/app_user.dart';
import '../../models/task_item.dart';
import '../../state/providers.dart';
import 'time_tracker_state.dart';

/// Holds the Time Tracker state and calls the services. No rules live here.
/// On sign-in it reads the running timer from SharePoint, so a timer survives
/// an app restart or a change of PC.
class TimeTrackerController extends Notifier<TimeTrackerState> {
  // Ignores the answer of a load that was replaced by a newer one.
  int _generation = 0;

  @override
  TimeTrackerState build() {
    // A different signed-in person gets a fresh state.
    ref.watch(currentUserProvider);
    Future.microtask(load);
    return const TimeTrackerState();
  }

  Future<void> load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final generation = ++_generation;
    state = state.copyWith(status: TimerLoadStatus.loading, clearError: true);
    try {
      final time = ref.read(timeTrackingServiceProvider);
      final active = await time.activeTimer(user);
      final day = await time.today(user);
      final tasks = await ref.read(taskServiceProvider).listPage(
            status: 'In Progress',
            assignedEmployeeId: user.employee.employeeId,
          );
      if (generation != _generation) return;
      state = state.copyWith(
        status: TimerLoadStatus.ready,
        active: active,
        clearActive: active == null,
        logs: day.logs.where((l) => !l.isActive).toList(),
        totalMinutes: day.totalMinutes -
            (active == null ? 0 : active.minutesAt(DateTime.now().toUtc())),
        myTasks: tasks.items,
      );
    } on GraphException catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        status: TimerLoadStatus.failed,
        errorMessage: e.userMessage,
      );
    }
  }

  /// Starts or resumes work on [task]. Returns an error message, or null.
  Future<String?> start(TaskItem task) => _run((user) async {
        await ref.read(timeTrackingServiceProvider).start(user, task);
        state = state.copyWith(clearPaused: true);
      });

  /// Ends the running segment and remembers the task for Resume.
  Future<String?> pause() => _run((user) async {
        final running = state.active;
        if (running == null) return;
        await ref.read(timeTrackingServiceProvider).stop(user, running);
        state = state.copyWith(pausedTaskCode: running.taskCode);
      });

  /// Ends the job. [workResult] is required.
  Future<String?> end(String workResult) => _run((user) async {
        final running = state.active;
        if (running == null) return;
        await ref.read(timeTrackingServiceProvider).stop(
              user,
              running,
              workResult: workResult,
              requireResult: true,
            );
        state = state.copyWith(clearPaused: true);
      });

  /// Runs [action], reloads, and returns the error message if there was one.
  Future<String?> _run(Future<void> Function(AppUser user) action) async {
    final user = ref.read(currentUserProvider);
    if (user == null || state.busy) return null;
    state = state.copyWith(busy: true, clearError: true);
    String? message;
    try {
      await action(user);
    } on RuleViolation catch (e) {
      message = e.message;
    } on GraphException catch (e) {
      message = e.userMessage;
    }
    state = state.copyWith(busy: false);
    await load();
    if (message != null) state = state.copyWith(errorMessage: message);
    return message;
  }
}

final timeTrackerControllerProvider =
    NotifierProvider<TimeTrackerController, TimeTrackerState>(
  TimeTrackerController.new,
);
