import 'malaysia_time.dart';

/// Office working time in Malaysia: which hours of which days count as work.
///
/// Public holidays and lunch breaks are not removed. Change [standard] if the
/// office hours change, and keep docs/UserManual.md in step.
class OfficeHours {
  const OfficeHours({
    this.startHour = 9,
    this.endHour = 18,
    this.workDays = const {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    },
  });

  /// Monday to Friday, 09:00 to 18:00 Malaysia time.
  static const standard = OfficeHours();

  final int startHour;
  final int endHour;

  /// `DateTime.monday` (1) to `DateTime.sunday` (7).
  final Set<int> workDays;

  /// Minutes of office time between [startUtc] and [endUtc].
  /// Zero when [endUtc] is not after [startUtc].
  double minutesBetween(DateTime startUtc, DateTime endUtc) {
    if (!endUtc.isAfter(startUtc)) return 0;
    // toMalaysiaTime shifts the clock by 8 hours. Its fields are the
    // Malaysia wall-clock time.
    final start = toMalaysiaTime(startUtc);
    final end = toMalaysiaTime(endUtc);
    var day = DateTime.utc(start.year, start.month, start.day);
    final lastDay = DateTime.utc(end.year, end.month, end.day);
    var seconds = 0;
    while (!day.isAfter(lastDay)) {
      if (workDays.contains(day.weekday)) {
        final open = day.add(Duration(hours: startHour));
        final close = day.add(Duration(hours: endHour));
        final from = start.isAfter(open) ? start : open;
        final to = end.isBefore(close) ? end : close;
        if (to.isAfter(from)) seconds += to.difference(from).inSeconds;
      }
      day = day.add(const Duration(days: 1));
    }
    return seconds / 60;
  }
}
