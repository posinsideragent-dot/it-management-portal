import '../../core/configuration/app_config.dart';
import '../../models/task_item.dart';
import '../../models/task_page.dart';
import '../api/graph_client.dart';

/// Everything the Tasks module needs from IT_Tasks.
abstract interface class TaskDirectory {
  /// One page. Filters use the indexed Status and AssignedEmployeeID columns.
  Future<TaskPage> listPage({
    String? status,
    String? assignedEmployeeId,
    String? nextLink,
  });

  /// The highest TaskCode in the list, or null when the list is empty.
  Future<String?> highestTaskCode();

  /// Creates a row. A duplicate TaskCode comes back as a [GraphException].
  Future<TaskItem> create(Map<String, Object?> fields);

  /// Updates with If-Match. A stale ETag comes back as HTTP 412.
  Future<TaskItem> update({
    required TaskItem current,
    required Map<String, Object?> fields,
  });
}

/// Reads and writes IT_Tasks through Microsoft Graph.
/// See docs/AdminSetup-DEV.md Part H for the list setup.
class TaskRepository implements TaskDirectory {
  TaskRepository(this._graph, this._config);

  final GraphClient _graph;
  final AppConfig _config;

  static const pageSize = 25;

  String get _itemsPath =>
      '/sites/${_config.siteId}/lists/${_config.tasksListId}/items';

  @override
  Future<TaskPage> listPage({
    String? status,
    String? assignedEmployeeId,
    String? nextLink,
  }) async {
    final Map<String, dynamic> json;
    if (nextLink != null) {
      json = await _graph.getUrl(nextLink);
    } else {
      final filters = <String>[
        if (status != null)
          "fields/${SpFields.status} eq '${_quote(status)}'",
        if (assignedEmployeeId != null)
          "fields/${SpFields.assignedEmployeeId} eq '${_quote(assignedEmployeeId)}'",
      ];
      json = await _graph.get(
        _itemsPath,
        query: {
          r'$expand': 'fields',
          r'$top': '$pageSize',
          if (filters.isNotEmpty) r'$filter': filters.join(' and '),
        },
      );
    }
    return TaskPage(
      items: _items(json).map(TaskItem.fromGraphItem).toList(),
      nextLink: json['@odata.nextLink'] as String?,
    );
  }

  @override
  Future<String?> highestTaskCode() async {
    final json = await _graph.get(
      _itemsPath,
      query: {
        r'$expand': 'fields',
        r'$orderby': 'fields/${SpFields.taskCode} desc',
        r'$top': '1',
      },
    );
    final items = _items(json);
    if (items.isEmpty) return null;
    return TaskItem.fromGraphItem(items.first).taskCode;
  }

  @override
  Future<TaskItem> create(Map<String, Object?> fields) async {
    final json = await _graph.post(_itemsPath, {'fields': fields});
    return TaskItem.fromGraphItem(json);
  }

  @override
  Future<TaskItem> update({
    required TaskItem current,
    required Map<String, Object?> fields,
  }) async {
    await _graph.patch(
      '$_itemsPath/${current.itemId}/fields',
      fields,
      headers: {'If-Match': current.etag},
    );
    // Read the row again so the caller holds the new ETag and saved values.
    final json = await _graph.get(
      '$_itemsPath/${current.itemId}',
      query: {r'$expand': 'fields'},
    );
    return TaskItem.fromGraphItem(json);
  }

  String _quote(String value) => value.replaceAll("'", "''");

  List<Map<String, dynamic>> _items(Map<String, dynamic> json) =>
      (json['value'] as List).cast<Map<String, dynamic>>();
}
