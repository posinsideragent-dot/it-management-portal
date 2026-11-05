import '../../models/employee.dart';

enum ActiveFilter {
  active('Active'),
  inactive('Inactive'),
  all('All');

  const ActiveFilter(this.label);
  final String label;

  /// Value for the server-side IsActive filter. Null means no filter.
  bool? get isActiveValue => switch (this) {
        ActiveFilter.active => true,
        ActiveFilter.inactive => false,
        ActiveFilter.all => null,
      };
}

enum LoadStatus { loading, ready, failed }

/// Everything the Employees screen needs to draw itself.
class EmployeeListState {
  const EmployeeListState({
    this.status = LoadStatus.loading,
    this.items = const [],
    this.nextLink,
    this.loadingMore = false,
    this.errorMessage,
    this.activeFilter = ActiveFilter.active,
    this.roleFilter,
    this.search = '',
  });

  final LoadStatus status;

  /// Rows loaded so far, across all pages.
  final List<Employee> items;
  final String? nextLink;
  final bool loadingMore;
  final String? errorMessage;
  final ActiveFilter activeFilter;

  /// Null means all roles. Applied to the rows already loaded.
  final String? roleFilter;

  /// Applied to the rows already loaded. Use "Load more" to search further.
  final String search;

  bool get hasMore => nextLink != null;

  /// Rows after the role and search filters.
  List<Employee> get visible {
    final query = search.trim().toLowerCase();
    return items.where((e) {
      if (roleFilter != null && e.appRole != roleFilter) return false;
      if (query.isEmpty) return true;
      return [e.name, e.email, e.employeeId, e.jobTitle, e.department]
          .any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  EmployeeListState copyWith({
    LoadStatus? status,
    List<Employee>? items,
    String? nextLink,
    bool clearNextLink = false,
    bool? loadingMore,
    String? errorMessage,
    bool clearError = false,
    ActiveFilter? activeFilter,
    String? roleFilter,
    bool clearRoleFilter = false,
    String? search,
  }) =>
      EmployeeListState(
        status: status ?? this.status,
        items: items ?? this.items,
        nextLink: clearNextLink ? null : (nextLink ?? this.nextLink),
        loadingMore: loadingMore ?? this.loadingMore,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        activeFilter: activeFilter ?? this.activeFilter,
        roleFilter: clearRoleFilter ? null : (roleFilter ?? this.roleFilter),
        search: search ?? this.search,
      );
}
