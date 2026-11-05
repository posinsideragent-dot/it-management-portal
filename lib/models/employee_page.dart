import 'employee.dart';

/// One page of employees. [nextLink] is null on the last page.
class EmployeePage {
  const EmployeePage({required this.items, this.nextLink});

  final List<Employee> items;
  final String? nextLink;
}
