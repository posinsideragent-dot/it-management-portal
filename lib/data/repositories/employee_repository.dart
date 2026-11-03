import '../../core/configuration/app_config.dart';
import '../../models/employee.dart';
import '../api/graph_client.dart';

/// Looks up an employee by Entra Object ID. Lets services be tested with fakes.
abstract interface class EmployeeLookup {
  Future<Employee?> findByEntraObjectId(String objectId);
}

/// Reads the IT_Employees list.
class EmployeeRepository implements EmployeeLookup {
  EmployeeRepository(this._graph, this._config);

  final GraphClient _graph;
  final AppConfig _config;

  String get _itemsPath =>
      '/sites/${_config.siteId}/lists/${_config.employeesListId}/items';

  /// Finds the employee whose EntraObjectID matches. Returns null if none.
  /// EntraObjectID must be an indexed column (see docs/SharePointSchema.md).
  @override
  Future<Employee?> findByEntraObjectId(String objectId) async {
    final safeId = objectId.replaceAll("'", "''");
    final json = await _graph.get(
      _itemsPath,
      query: {
        r'$expand': 'fields',
        r'$filter': "fields/${SpFields.entraObjectId} eq '$safeId'",
        r'$top': '1',
      },
    );
    final items = (json['value'] as List).cast<Map<String, dynamic>>();
    return items.isEmpty ? null : Employee.fromGraphItem(items.first);
  }

  /// First page of employees. Real screens must use paging.
  Future<List<Employee>> listFirstPage({int top = 25}) async {
    final json = await _graph.get(
      _itemsPath,
      query: {r'$expand': 'fields', r'$top': '$top'},
    );
    final items = (json['value'] as List).cast<Map<String, dynamic>>();
    return items.map(Employee.fromGraphItem).toList();
  }
}
