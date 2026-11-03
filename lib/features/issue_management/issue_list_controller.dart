import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/graph_client.dart';
import '../../models/app_user.dart';
import '../../models/issue.dart';
import '../../services/issue_service.dart';
import '../../state/providers.dart';
import 'issue_list_state.dart';

/// Holds the Issues list and calls IssueService. No business rules live here.
class IssueListController extends Notifier<IssueListState> {
  // Ignores the answer of a load that was replaced by a newer one.
  int _generation = 0;

  @override
  IssueListState build() {
    // A different signed-in person gets a fresh list.
    ref.watch(currentUserProvider);
    Future.microtask(load);
    return const IssueListState();
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      status: IssueLoadStatus.loading,
      items: const [],
      clearNextLink: true,
      clearError: true,
    );
    try {
      final page = await ref.read(issueServiceProvider).listPage(
            status: state.statusFilter?.label,
            assignedEmployeeId: _mineFilter(),
          );
      if (generation != _generation) return;
      state = state.copyWith(
        status: IssueLoadStatus.ready,
        items: page.items,
        nextLink: page.nextLink,
        clearNextLink: page.nextLink == null,
      );
    } on GraphException catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        status: IssueLoadStatus.failed,
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
      final page = await ref.read(issueServiceProvider).listPage(nextLink: link);
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

  Future<void> setStatusFilter(IssueStatus? status) async {
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

  /// The methods below throw [IssueRuleException] or [GraphException].
  /// The screen shows the message. The list reloads after a successful save.
  Future<void> create(IssueDraft draft) async {
    await ref.read(issueServiceProvider).create(_actor(), draft);
    await load();
  }

  Future<void> edit(IssueItem current, IssueDraft draft) async {
    await ref.read(issueServiceProvider).update(_actor(), current, draft);
    await load();
  }

  Future<void> assign(IssueItem current, String employeeId) async {
    await ref.read(issueServiceProvider).assign(_actor(), current, employeeId);
    await load();
  }

  Future<void> changeStatus(
    IssueItem current,
    IssueStatus to, {
    String remarks = '',
  }) async {
    await ref
        .read(issueServiceProvider)
        .changeStatus(_actor(), current, to, remarks: remarks);
    await load();
  }

  String? _mineFilter() {
    if (!state.mineOnly) return null;
    return ref.read(currentUserProvider)?.employee.employeeId;
  }

  AppUser _actor() {
    final user = ref.read(currentUserProvider);
    if (user == null) throw IssueRuleException('You are not signed in.');
    return user;
  }
}

final issueListControllerProvider =
    NotifierProvider<IssueListController, IssueListState>(
  IssueListController.new,
);
