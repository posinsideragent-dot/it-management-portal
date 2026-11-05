/// Makes codes such as TASK-2026-00001 or TL-2026-000001.
///
/// The number restarts at 1 each year. The next number is the highest number
/// of the current year plus one. If two people pick the same number,
/// SharePoint rejects the second (the code column enforces unique values)
/// and the service tries again.
class YearlyCode {
  const YearlyCode(this.prefix, this.width);

  final String prefix;
  final int width;

  RegExp get _pattern => RegExp('^${RegExp.escape(prefix)}-(\\d{4})-(\\d+)\$');

  /// [highest] is the largest code in the list, or null for an empty list.
  /// [year] is the current Malaysia year.
  /// Returns null when [highest] is badly formatted or from a later year
  /// (a wrong PC clock).
  String? next(String? highest, int year) {
    if (highest == null || highest.isEmpty) return format(year, 1);
    final match = _pattern.firstMatch(highest);
    if (match == null) return null;
    final highestYear = int.parse(match.group(1)!);
    if (highestYear > year) return null;
    if (highestYear < year) return format(year, 1);
    return format(year, int.parse(match.group(2)!) + 1);
  }

  String format(int year, int number) =>
      '$prefix-$year-${number.toString().padLeft(width, '0')}';
}
