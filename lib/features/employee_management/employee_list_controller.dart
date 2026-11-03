import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/graph_client.dart';
import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../models/employee_draft.dart';
import '../../services/employee_service.dart';
import '../../state/providers.dart';
import 'employee_list_state.dart';

/// Holds the Employees list and calls [EmployeeService]. No business rules
/// live here.
class EmployeeListController extends Notifier<EmployeeListState> {
  // Ignores the answer of a load that was replaced by a newer one.
  int _generation = 0;

  @override
  EmployeeListState build() {
    // A different signed-in person gets a fresh list.
    ref.watch(currentUserProvider);
    Future.microtask(load);
    return const EmployeeListState();
  }

  EmployeeService get _service => ref.read(employeeServiceProvider);

  /// Loads the first page again.
  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      status: LoadStatus.loading,
      items: const [],
      clearNextLink: true,
      clearError: true,
    );
    try {
      final page = await _service.listPage(
        isActive: state.activeFilter.isActiveValue,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        status: LoadStatus.ready,
        items: page.items,
        nextLink: page.nextLink,
        clearNextLink: page.nextLink == null,
      );
    } on GraphException catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        status: LoadStatus.failed,
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
      final page = await _service.listPage(nextLink: link);
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

  Future<void> setActiveFilter(ActiveFilter filter) async {
    if (filter == state.activeFilter) return;
    state = state.copyWith(activeFilter: filter);
    await load();
  }

  void setRoleFilter(String? role) => state = role == null
      ? state.copyWith(clearRoleFilter: true)
      : state.copyWith(roleFilter: role);

  void setSearch(String text) => state = state.copyWith(search: text);

  /// The methods below throw [EmployeeRuleException] or [GraphException].
  /// The screen shows the message. The list reloads after a successful save.
  Future<void> create(EmployeeDraft draft) async {
    await _service.create(_actor(), draft);
    await load();
  }

  Future<void> edit(Employee current, EmployeeDraft draft) async {
    await _service.update(_actor(), current, draft);
    await load();
  }

  Future<void> setActive(Employee current, {required bool active}) async {
    await _service.setActive(_actor(), current, active: active);
    await load();
  }

  AppUser _actor() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw EmployeeRuleException('You are not signed in.');
    }
    return user;
  }
}

final employeeListControllerProvider =
    NotifierProvider<EmployeeListController, EmployeeListState>(
  EmployeeListController.new,
);
