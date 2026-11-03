/// Makes TaskCodes such as TASK-2026-00001.
///
/// The number restarts at 00001 each year. The next number is the highest
/// number of the current year plus one. If two people pick the same number,
/// SharePoint rejects the second (TaskCode enforces unique values) and the
/// service tries again.
class TaskCodes {
  const TaskCodes._();

  static final _pattern = RegExp(r'^TASK-(\d{4})-(\d+)$');

  /// [highest] is the largest TaskCode in the list, or null for an empty list.
  /// [year] is the current Malaysia year.
  /// Returns null when [highest] is badly formatted or from a later year
  /// (a wrong PC clock).
  static String? next(String? highest, int year) {
    if (highest == null || highest.isEmpty) return format(year, 1);
    final match = _pattern.firstMatch(highest);
    if (match == null) return null;
    final highestYear = int.parse(match.group(1)!);
    if (highestYear > year) return null;
    if (highestYear < year) return format(year, 1);
    return format(year, int.parse(match.group(2)!) + 1);
  }

  static String format(int year, int number) =>
      'TASK-$year-${number.toString().padLeft(5, '0')}';
}
