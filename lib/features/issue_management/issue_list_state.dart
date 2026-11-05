import '../../models/issue.dart';

enum IssueLoadStatus { loading, ready, failed }

/// Everything the Issues screen needs to draw itself.
class IssueListState {
  const IssueListState({
    this.status = IssueLoadStatus.loading,
    this.items = const [],
    this.nextLink,
    this.loadingMore = false,
    this.errorMessage,
    this.statusFilter,
    this.mineOnly = false,
    this.search = '',
  });

  final IssueLoadStatus status;

  /// Rows loaded so far, across all pages.
  final List<IssueItem> items;
  final String? nextLink;
  final bool loadingMore;
  final String? errorMessage;

  /// Null means all statuses. Applied by SharePoint (indexed column).
  final IssueStatus? statusFilter;

  /// Only issues assigned to me. Applied by SharePoint (indexed column).
  final bool mineOnly;

  /// Applied to the rows already loaded. Use "Load more" to search further.
  final String search;

  bool get hasMore => nextLink != null;

  List<IssueItem> get visible {
    final query = search.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where(
          (i) =>
              i.issueCode.toLowerCase().contains(query) ||
              i.title.toLowerCase().contains(query) ||
              i.assignedEmployeeId.toLowerCase().contains(query),
        )
        .toList();
  }

  IssueListState copyWith({
    IssueLoadStatus? status,
    List<IssueItem>? items,
    String? nextLink,
    bool clearNextLink = false,
    bool? loadingMore,
    String? errorMessage,
    bool clearError = false,
    IssueStatus? statusFilter,
    bool clearStatusFilter = false,
    bool? mineOnly,
    String? search,
  }) =>
      IssueListState(
        status: status ?? this.status,
        items: items ?? this.items,
        nextLink: clearNextLink ? null : (nextLink ?? this.nextLink),
        loadingMore: loadingMore ?? this.loadingMore,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        statusFilter:
            clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
        mineOnly: mineOnly ?? this.mineOnly,
        search: search ?? this.search,
      );
}
