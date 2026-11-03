import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/graph_client.dart';
import '../../models/app_user.dart';
import '../../models/task_draft.dart';
import '../../models/task_enums.dart';
import '../../models/task_item.dart';
import '../../services/task_service.dart';
import '../../state/providers.dart';
import 'task_list_state.dart';

/// Holds the Tasks list and calls TaskService. No business rules live here.
class TaskListController extends Notifier<TaskListState> {
  // Ignores the answer of a load that was replaced by a newer one.
  int _generation = 0;

  @override
  TaskListState build() {
    // A different signed-in person gets a fresh list.
    ref.watch(currentUserProvider);
    Future.microtask(load);
    return const TaskListState();
  }

  /// Loads the first page again.
  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      status: TaskLoadStatus.loading,
      items: const [],
      clearNextLink: true,
      clearError: true,
    );
    try {
      final page = await ref.read(taskServiceProvider).listPage(
            status: state.statusFilter?.label,
            assignedEmployeeId: _mineFilter(),
          );
      if (generation != _generation) return;
      state = state.copyWith(
        status: TaskLoadStatus.ready,
        items: page.items,
        nextLink: page.nextLink,
        clearNextLink: page.nextLink == null,
      );
    } on GraphException catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        status: TaskLoadStatus.failed,
        errorMessage: e.userMessage,
      );
    }
  }

  Future<void> loadMore() async {
    final link = state.nextLink;
    if (link == null || state.loadingMore) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await ref.read(taskServiceProvider).listPage(nextLink: link);
      if (generation != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextLink: page.nextLink,
        clearNextLink: page.nextLink == null,
        loadingMore: false,
      );
    } on GraphException catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(loadingMore: false, errorMessage: e.userMessage);
    }
  }

  Future<void> setStatusFilter(TaskStatus? status) async {
    state = status == null
        ? state.copyWith(clearStatusFilter: true)
        : state.copyWith(statusFilter: status);
    await load();
  }

  Future<void> setMineOnly(bool value) async {
    state = state.copyWith(mineOnly: value);
    await load();
  }

  void setSearch(String text) => state = state.copyWith(search: text);

  /// The methods below throw [TaskRuleException] or [GraphException].
  /// The screen shows the message. The list reloads after a successful save.
  Future<void> create(TaskDraft draft) async {
    await ref.read(taskServiceProvider).create(_actor(), draft);
    await load();
  }

  Future<void> edit(TaskItem current, TaskDraft draft) async {
    await ref.read(taskServiceProvider).update(_actor(), current, draft);
    await load();
  }

  Future<void> changeStatus(
    TaskItem current,
    TaskStatus to, {
    String remarks = '',
  }) async {
    await ref
        .read(taskServiceProvider)
        .changeStatus(_actor(), current, to, remarks: remarks);
    await load();
  }

  Future<void> updateProgress(TaskItem current, int progress) async {
    await ref
        .read(taskServiceProvider)
        .updateProgress(_actor(), current, progress);
    await load();
  }

  String? _mineFilter() {
    if (!state.mineOnly) return null;
    return ref.read(currentUserProvider)?.employee.employeeId;
  }

  AppUser _actor() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw TaskRuleException('You are not signed in.');
    }
    return user;
  }
}

final taskListControllerProvider =
    NotifierProvider<TaskListController, TaskListState>(
  TaskListController.new,
);
