import '../../core/configuration/app_config.dart';
import '../../models/time_log.dart';
import '../api/graph_client.dart';

/// Everything the Time Tracker needs from IT_TimeLogs.
abstract interface class TimeLogDirectory {
  /// The employee's running timer, or null. Uses the unique ActiveTimerKey.
  Future<TimeLog?> findActive(String employeeId);

  /// The employee's logs that started at or after [sinceUtc], newest first.
  /// Bounded: at most [TimeLogRepository.maxPages] pages are read.
  Future<List<TimeLog>> listSince(String employeeId, DateTime sinceUtc);

  /// The highest TimeLogCode in the list, or null when the list is empty.
  Future<String?> highestCode();

  /// Creates a row. A duplicate code or active key comes back as a
  /// [GraphException].
  Future<TimeLog> create(Map<String, Object?> fields);

  /// Updates with If-Match. A stale ETag comes back as HTTP 412.
  Future<TimeLog> update({
    required TimeLog current,
    required Map<String, Object?> fields,
  });
}

/// Reads and writes IT_TimeLogs through Microsoft Graph.
/// EmployeeID, TaskCode, StartTimeUTC, TimerStatus and ActiveTimerKey are
/// indexed (see scripts/itdmp_lists.json).
class TimeLogRepository implements TimeLogDirectory {
  TimeLogRepository(this._graph, this._config);

  final GraphClient _graph;
  final AppConfig _config;

  static const pageSize = 50;
  static const maxPages = 4;

  String get _itemsPath =>
      '/sites/${_config.siteId}/lists/${_config.timeLogsListId}/items';

  @override
  Future<TimeLog?> findActive(String employeeId) async {
    final json = await _graph.get(
      _itemsPath,
      query: {
        r'$expand': 'fields',
        r'$top': '2',
        r'$filter':
            "fields/${SpFields.activeTimerKey} eq '${_quote(TimeLog.activeKeyFor(employeeId))}'",
      },
    );
    final rows = _items(json).map(TimeLog.fromGraphItem).toList();
    if (rows.isEmpty) return null;
    // The key is unique, so two rows would mean a broken list setup.
    if (rows.length > 1) {
      throw StateError('More than one active timer found for $employeeId.');
    }
    return rows.first;
  }

  @override
  Future<List<TimeLog>> listSince(String employeeId, DateTime sinceUtc) async {
    var json = await _graph.get(
      _itemsPath,
      query: {
        r'$expand': 'fields',
        r'$top': '$pageSize',
        r'$filter': "fields/${SpFields.employeeId} eq '${_quote(employeeId)}' "
            "and fields/${SpFields.startTimeUtc} ge '${sinceUtc.toUtc().toIso8601String()}'",
      },
    );
    final rows = <TimeLog>[..._items(json).map(TimeLog.fromGraphItem)];
    var pages = 1;
    while (json['@odata.nextLink'] is String && pages < maxPages) {
      json = await _graph.getUrl(json['@odata.nextLink'] as String);
      rows.addAll(_items(json).map(TimeLog.fromGraphItem));
      pages++;
    }
    rows.sort((a, b) => b.startUtc.compareTo(a.startUtc));
    return rows;
  }

  @override
  Future<String?> highestCode() async {
    final json = await _graph.get(
      _itemsPath,
      query: {
        r'$expand': 'fields',
        r'$orderby': 'fields/${SpFields.timeLogCode} desc',
        r'$top': '1',
      },
    );
    final items = _items(json);
    if (items.isEmpty) return null;
    return TimeLog.fromGraphItem(items.first).timeLogCode;
  }

  @override
  Future<TimeLog> create(Map<String, Object?> fields) async {
    final json = await _graph.post(_itemsPath, {'fields': fields});
    return TimeLog.fromGraphItem(json);
  }

  @override
  Future<TimeLog> update({
    required TimeLog current,
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
    return TimeLog.fromGraphItem(json);
  }

  String _quote(String value) => value.replaceAll("'", "''");

  List<Map<String, dynamic>> _items(Map<String, dynamic> json) =>
      (json['value'] as List).cast<Map<String, dynamic>>();
}
