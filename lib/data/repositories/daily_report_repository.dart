import '../../core/configuration/app_config.dart';
import '../../models/daily_report.dart';
import '../api/graph_client.dart';

/// One page of reports. [nextLink] is null on the last page.
class DailyReportPage {
  const DailyReportPage({required this.items, this.nextLink});

  final List<DailyReport> items;
  final String? nextLink;
}

/// Everything the Daily Reports module needs from IT_DailyReports.
abstract interface class DailyReportDirectory {
  /// One page, newest report date first. Filters use indexed columns.
  Future<DailyReportPage> listPage({
    String? employeeId,
    String? status,
    String? nextLink,
  });

  /// Creates a row. A duplicate ReportCode comes back as a [GraphException].
  Future<DailyReport> create(Map<String, Object?> fields);

  /// Updates with If-Match. A stale ETag comes back as HTTP 412.
  Future<DailyReport> update({
    required DailyReport current,
    required Map<String, Object?> fields,
  });
}

/// Reads and writes IT_DailyReports through Microsoft Graph.
/// EmployeeID, ReportDate, SubmissionStatus and ReportCode are indexed.
class DailyReportRepository implements DailyReportDirectory {
  DailyReportRepository(this._graph, this._config);

  final GraphClient _graph;
  final AppConfig _config;

  static const pageSize = 25;

  String get _itemsPath =>
      '/sites/${_config.siteId}/lists/${_config.dailyReportsListId}/items';

  @override
  Future<DailyReportPage> listPage({
    String? employeeId,
    String? status,
    String? nextLink,
  }) async {
    final Map<String, dynamic> json;
    if (nextLink != null) {
      json = await _graph.getUrl(nextLink);
    } else {
      final filters = <String>[
        if (employeeId != null)
          "fields/${SpFields.employeeId} eq '${_quote(employeeId)}'",
        if (status != null)
          "fields/${SpFields.submissionStatus} eq '${_quote(status)}'",
      ];
      json = await _graph.get(
        _itemsPath,
        query: {
          r'$expand': 'fields',
          r'$top': '$pageSize',
          r'$orderby': 'fields/${SpFields.reportDate} desc',
          if (filters.isNotEmpty) r'$filter': filters.join(' and '),
        },
      );
    }
    return DailyReportPage(
      items: _items(json).map(DailyReport.fromGraphItem).toList(),
      nextLink: json['@odata.nextLink'] as String?,
    );
  }

  @override
  Future<DailyReport> create(Map<String, Object?> fields) async {
    final json = await _graph.post(_itemsPath, {'fields': fields});
    return DailyReport.fromGraphItem(json);
  }

  @override
  Future<DailyReport> update({
    required DailyReport current,
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
    return DailyReport.fromGraphItem(json);
  }

  String _quote(String value) => value.replaceAll("'", "''");

  List<Map<String, dynamic>> _items(Map<String, dynamic> json) =>
      (json['value'] as List).cast<Map<String, dynamic>>();
}
