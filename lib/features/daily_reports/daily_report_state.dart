import '../../models/daily_report.dart';

enum ReportLoadStatus { loading, ready, failed }

/// Everything the Daily Reports screen needs to draw itself.
class DailyReportState {
  const DailyReportState({
    this.status = ReportLoadStatus.loading,
    this.items = const [],
    this.nextLink,
    this.loadingMore = false,
    this.errorMessage,
    this.statusFilter,
    this.mineOnly = true,
  });

  final ReportLoadStatus status;

  /// Rows loaded so far, across all pages.
  final List<DailyReport> items;
  final String? nextLink;
  final bool loadingMore;
  final String? errorMessage;

  /// Null means all statuses. Applied by SharePoint (indexed column).
  final SubmissionStatus? statusFilter;

  /// Only my reports. Leads can turn this off to see everyone's.
  final bool mineOnly;

  bool get hasMore => nextLink != null;

  DailyReportState copyWith({
    ReportLoadStatus? status,
    List<DailyReport>? items,
    String? nextLink,
    bool clearNextLink = false,
    bool? loadingMore,
    String? errorMessage,
    bool clearError = false,
    SubmissionStatus? statusFilter,
    bool clearStatusFilter = false,
    bool? mineOnly,
  }) =>
      DailyReportState(
        status: status ?? this.status,
        items: items ?? this.items,
        nextLink: clearNextLink ? null : (nextLink ?? this.nextLink),
        loadingMore: loadingMore ?? this.loadingMore,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        statusFilter:
            clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
        mineOnly: mineOnly ?? this.mineOnly,
      );
}
