import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/graph_client.dart';
import '../../models/app_user.dart';
import '../../models/daily_report.dart';
import '../../services/daily_report_service.dart';
import '../../state/providers.dart';
import 'daily_report_state.dart';

/// Holds the Daily Reports list and calls DailyReportService.
/// No business rules live here.
class DailyReportController extends Notifier<DailyReportState> {
  // Ignores the answer of a load that was replaced by a newer one.
  int _generation = 0;

  @override
  DailyReportState build() {
    // A different signed-in person gets a fresh list.
    ref.watch(currentUserProvider);
    Future.microtask(load);
    return const DailyReportState();
  }

  Future<void> load() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final generation = ++_generation;
    state = state.copyWith(
      status: ReportLoadStatus.loading,
      items: const [],
      clearNextLink: true,
      clearError: true,
    );
    try {
      final page = await ref.read(dailyReportServiceProvider).listPage(
            user,
            mineOnly: state.mineOnly,
            status: state.statusFilter?.label,
          );
      if (generation != _generation) return;
      state = state.copyWith(
        status: ReportLoadStatus.ready,
        items: page.items,
        nextLink: page.nextLink,
        clearNextLink: page.nextLink == null,
      );
    } on GraphException catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(
        status: ReportLoadStatus.failed,
        errorMessage: e.userMessage,
      );
    }
  }

  Future<void> loadMore() async {
    final user = ref.read(currentUserProvider);
    final link = state.nextLink;
    if (user == null || link == null || state.loadingMore) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final page = await ref
          .read(dailyReportServiceProvider)
          .listPage(user, nextLink: link);
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

  Future<void> setStatusFilter(SubmissionStatus? status) async {
    state = status == null
        ? state.copyWith(clearStatusFilter: true)
        : state.copyWith(statusFilter: status);
    await load();
  }

  Future<void> setMineOnly(bool value) async {
    state = state.copyWith(mineOnly: value);
    await load();
  }

  /// The methods below throw [DailyReportRuleException] or [GraphException].
  /// The screen shows the message. The list reloads after a successful save.
  Future<void> create(DailyReportDraft draft, {required bool submit}) async {
    await ref
        .read(dailyReportServiceProvider)
        .create(_actor(), draft, submit: submit);
    await load();
  }

  Future<void> edit(
    DailyReport current,
    DailyReportDraft draft, {
    required bool submit,
  }) async {
    await ref
        .read(dailyReportServiceProvider)
        .update(_actor(), current, draft, submit: submit);
    await load();
  }

  Future<void> submit(DailyReport current) async {
    await ref.read(dailyReportServiceProvider).submit(_actor(), current);
    await load();
  }

  Future<void> review(
    DailyReport current, {
    required bool accept,
    String remarks = '',
  }) async {
    await ref
        .read(dailyReportServiceProvider)
        .review(_actor(), current, accept: accept, remarks: remarks);
    await load();
  }

  AppUser _actor() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw DailyReportRuleException('You are not signed in.');
    }
    return user;
  }
}

final dailyReportControllerProvider =
    NotifierProvider<DailyReportController, DailyReportState>(
  DailyReportController.new,
);
