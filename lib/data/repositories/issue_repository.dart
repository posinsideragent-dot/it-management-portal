import '../../core/configuration/app_config.dart';
import '../../models/issue.dart';
import '../api/graph_client.dart';

/// One page of issues. [nextLink] is null on the last page.
class IssuePage {
  const IssuePage({required this.items, this.nextLink});

  final List<IssueItem> items;
  final String? nextLink;
}

/// Everything the Issues module needs from IT_Issues.
abstract interface class IssueDirectory {
  /// One page. Filters use the indexed Status and AssignedEmployeeID columns.
  Future<IssuePage> listPage({
    String? status,
    String? assignedEmployeeId,
    String? nextLink,
  });

  /// The highest IssueCode in the list, or null when the list is empty.
  Future<String?> highestIssueCode();

  /// Creates a row. A duplicate IssueCode comes back as a [GraphException].
  Future<IssueItem> create(Map<String, Object?> fields);

  /// Updates with If-Match. A stale ETag comes back as HTTP 412.
  Future<IssueItem> update({
    required IssueItem current,
    required Map<String, Object?> fields,
  });
}

/// Reads and writes IT_Issues through Microsoft Graph.
class IssueRepository implements IssueDirectory {
  IssueRepository(this._graph, this._config);

  final GraphClient _graph;
  final AppConfig _config;

  static const pageSize = 25;

  String get _itemsPath =>
      '/sites/${_config.siteId}/lists/${_config.issuesListId}/items';

  @override
  Future<IssuePage> listPage({
    String? status,
    String? assignedEmployeeId,
    String? nextLink,
  }) async {
    final Map<String, dynamic> json;
    if (nextLink != null) {
      json = await _graph.getUrl(nextLink);
    } else {
      final filters = <String>[
        if (status != null) "fields/${SpFields.status} eq '${_quote(status)}'",
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
    return IssuePage(
      items: _items(json).map(IssueItem.fromGraphItem).toList(),
      nextLink: json['@odata.nextLink'] as String?,
    );
  }

  @override
  Future<String?> highestIssueCode() async {
    final json = await _graph.get(
      _itemsPath,
      query: {
        r'$expand': 'fields',
        r'$orderby': 'fields/${SpFields.issueCode} desc',
        r'$top': '1',
      },
    );
    final items = _items(json);
    if (items.isEmpty) return null;
    return IssueItem.fromGraphItem(items.first).issueCode;
  }

  @override
  Future<IssueItem> create(Map<String, Object?> fields) async {
    final json = await _graph.post(_itemsPath, {'fields': fields});
    return IssueItem.fromGraphItem(json);
  }

  @override
  Future<IssueItem> update({
    required IssueItem current,
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
    return IssueItem.fromGraphItem(json);
  }

  String _quote(String value) => value.replaceAll("'", "''");

  List<Map<String, dynamic>> _items(Map<String, dynamic> json) =>
      (json['value'] as List).cast<Map<String, dynamic>>();
}
