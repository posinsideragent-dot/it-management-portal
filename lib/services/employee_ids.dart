/// Makes EmployeeIDs such as EMP-0001.
///
/// The next number is the highest existing number plus one. Two people can
/// still pick the same number at the same moment. SharePoint then rejects the
/// second one, because EmployeeID enforces unique values. The service reads
/// the highest number again and tries once more.
class EmployeeIds {
  const EmployeeIds._();

  static final _pattern = RegExp(r'^EMP-(\d+)$');

  /// [highest] is the largest existing EmployeeID, or null for an empty list.
  /// Returns null when [highest] does not match the format.
  static String? next(String? highest) {
    if (highest == null || highest.isEmpty) return format(1);
    final match = _pattern.firstMatch(highest);
    if (match == null) return null;
    return format(int.parse(match.group(1)!) + 1);
  }

  static String format(int number) =>
      'EMP-${number.toString().padLeft(4, '0')}';
}
