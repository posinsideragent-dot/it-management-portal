import '../../core/configuration/app_config.dart';
import '../api/graph_client.dart';

/// One item of the throwaway IT_PoC_Test list.
class PocItem {
  const PocItem({
    required this.id,
    required this.etag,
    required this.title,
    required this.status,
  });

  final String id;

  /// Used as the If-Match value on updates.
  final String etag;
  final String title;
  final String status;
}

/// Create and update test items in IT_PoC_Test.
/// Proves create, update and ETag checks. Delete this after the gate passes.
class PocTestRepository {
  PocTestRepository(this._graph, this._config);

  final GraphClient _graph;
  final AppConfig _config;

  String get _listPath =>
      '/sites/${_config.siteId}/lists/${_config.pocTestListId}';

  Future<PocItem> create({required String title, required String note}) async {
    final json = await _graph.post('$_listPath/items', {
      'fields': {
        SpFields.title: title,
        SpFields.testNote: note,
        SpFields.testStatus: 'New',
      },
    });
    final fields = (json['fields'] as Map<String, dynamic>?) ?? const {};
    return PocItem(
      id: json['id'].toString(),
      etag: (json['eTag'] ?? json['@odata.etag'] ?? '').toString(),
      title: (fields[SpFields.title] ?? title).toString(),
      status: (fields[SpFields.testStatus] ?? 'New').toString(),
    );
  }

  /// Updates the item. Sends [etag] as If-Match, so a stale ETag must fail
  /// with HTTP 412.
  Future<PocItem> update({
    required PocItem item,
    required String etag,
    required String note,
  }) async {
    final json = await _graph.patch(
      '$_listPath/items/${item.id}/fields',
      {
        SpFields.testNote: note,
        SpFields.testStatus: 'Updated',
      },
      headers: {'If-Match': etag},
    );
    return PocItem(
      id: item.id,
      etag: (json['@odata.etag'] ?? etag).toString(),
      title: item.title,
      status: (json[SpFields.testStatus] ?? 'Updated').toString(),
    );
  }
}
