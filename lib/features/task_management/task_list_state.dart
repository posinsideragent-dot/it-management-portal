import '../../models/task_enums.dart';
import '../../models/task_item.dart';

enum TaskLoadStatus { loading, ready, failed }

/// Everything the Tasks screen needs to draw itself.
class TaskListState {
  const TaskListState({
    this.status = TaskLoadStatus.loading,
    this.items = const [],
    this.nextLink,
    this.loadingMore = false,
    this.errorMessage,
    this.statusFilter,
    this.mineOnly = false,
    this.search = '',
  });

  final TaskLoadStatus status;

  /// Rows loaded so far, across all pages.
  final List<TaskItem> items;
  final String? nextLink;
  final bool loadingMore;
  final String? errorMessage;

  /// Null means all statuses. Applied by SharePoint (indexed column).
  final TaskStatus? statusFilter;

  /// Only tasks assigned to me. Applied by SharePoint (indexed column).
  final bool mineOnly;

  /// Applied to the rows already loaded. Use "Load more" to search further.
  final String search;

  bool get hasMore => nextLink != null;

  List<TaskItem> get visible {
    final query = search.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where(
          (t) => [t.taskCode, t.title, t.assignedEmployeeId, t.projectCode]
              .any((value) => value.toLowerCase().contains(query)),
        )
        .toList();
  }

  TaskListState copyWith({
    TaskLoadStatus? status,
    List<TaskItem>? items,
    String? nextLink,
    bool clearNextLink = false,
    bool? loadingMore,
    String? errorMessage,
    bool clearError = false,
    TaskStatus? statusFilter,
    bool clearStatusFilter = false,
    bool? mineOnly,
    String? search,
  }) =>
      TaskListState(
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
