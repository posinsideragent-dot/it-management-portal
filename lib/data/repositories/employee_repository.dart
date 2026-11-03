import '../../core/configuration/app_config.dart';
import '../../models/employee.dart';
import '../../models/employee_page.dart';
import '../api/graph_client.dart';

/// Looks up an employee by Entra Object ID. Lets services be tested with fakes.
abstract interface class EmployeeLookup {
  Future<Employee?> findByEntraObjectId(String objectId);
}

/// Everything the Employees module needs from IT_Employees.
abstract interface class EmployeeDirectory implements EmployeeLookup {
  /// One page. [isActive] filters on the indexed IsActive column.
  /// Pass the previous page's `nextLink` to get the next page.
  Future<EmployeePage> listPage({bool? isActive, String? nextLink});

  Future<Employee?> findByEmployeeId(String employeeId);

  /// The highest EmployeeID in the list, or null when the list is empty.
  Future<String?> highestEmployeeId();

  /// Creates a row. A duplicate unique value comes back as a [GraphException].
  Future<Employee> create(Map<String, Object?> fields);

  /// Updates with If-Match. A stale ETag comes back as HTTP 412.
  Future<Employee> update({
    required Employee current,
    required Map<String, Object?> fields,
  });
}

/// Reads and writes the IT_Employees list through Microsoft Graph.
///
/// Needs these SharePoint settings (docs/SharePointSchema.md):
/// EmployeeID, EntraObjectID, Email and IsActive indexed;
/// EmployeeID and EntraObjectID set to enforce unique values.
class EmployeeRepository implements EmployeeDirectory {
  EmployeeRepository(this._graph, this._config);

  final GraphClient _graph;
  final AppConfig _config;

  static const pageSize = 25;

  String get _itemsPath =>
      '/sites/${_config.siteId}/lists/${_config.employeesListId}/items';

  /// Finds the employee whose EntraObjectID matches. Returns null if none.
  /// EntraObjectID must be an indexed column (see docs/SharePointSchema.md).
  @override
  Future<Employee?> findByEntraObjectId(String objectId) =>
      _findOne(SpFields.entraObjectId, objectId);

  @override
  Future<Employee?> findByEmployeeId(String employeeId) =>
      _findOne(SpFields.employeeId, employeeId);

  Future<Employee?> _findOne(String field, String value) async {
    final safe = value.replaceAll("'", "''");
    final json = await _graph.get(
      _itemsPath,
      query: {
        r'$expand': 'fields',
        r'$filter': "fields/$field eq '$safe'",
        r'$top': '1',
      },
    );
    final items = _items(json);
    return items.isEmpty ? null : Employee.fromGraphItem(items.first);
  }

  @override
  Future<EmployeePage> listPage({bool? isActive, String? nextLink}) async {
    final Map<String, dynamic> json;
    if (nextLink != null) {
      json = await _graph.getUrl(nextLink);
    } else {
      json = await _graph.get(
        _itemsPath,
        query: {
          r'$expand': 'fields',
          r'$top': '$pageSize',
          if (isActive != null)
            r'$filter': 'fields/${SpFields.isActive} eq ${isActive ? 1 : 0}',
        },
      );
    }
    return EmployeePage(
      items: _items(json).map(Employee.fromGraphItem).toList(),
      nextLink: json['@odata.nextLink'] as String?,
    );
  }

  @override
  Future<String?> highestEmployeeId() async {
    final json = await _graph.get(
      _itemsPath,
      query: {
        r'$expand': 'fields',
        r'$orderby': 'fields/${SpFields.employeeId} desc',
        r'$top': '1',
      },
    );
    final items = _items(json);
    if (items.isEmpty) return null;
    return Employee.fromGraphItem(items.first).employeeId;
  }

  @override
  Future<Employee> create(Map<String, Object?> fields) async {
    final json = await _graph.post(_itemsPath, {'fields': fields});
    return Employee.fromGraphItem(json);
  }

  @override
  Future<Employee> update({
    required Employee current,
    required Map<String, Object?> fields,
  }) async {
    await _graph.patch(
      '$_itemsPath/${current.itemId}/fields',
      fields,
      headers: {'If-Match': current.etag},
    );
    // Read the row again so the caller holds the new ETag and the saved values.
    final json = await _graph.get(
      '$_itemsPath/${current.itemId}',
      query: {r'$expand': 'fields'},
    );
    return Employee.fromGraphItem(json);
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> json) =>
      (json['value'] as List).cast<Map<String, dynamic>>();
}
