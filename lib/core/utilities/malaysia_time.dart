/// All dates are stored in UTC. Show them in Malaysia time (UTC+8).
/// Malaysia has no daylight saving, so a fixed offset is correct.
const malaysiaOffset = Duration(hours: 8);

DateTime toMalaysiaTime(DateTime value) =>
    (value.isUtc ? value : value.toUtc()).add(malaysiaOffset);

/// Format: `2026-11-03 14:05`.
String formatMalaysiaTime(DateTime value) {
  final t = toMalaysiaTime(value);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// The calendar year in Malaysia at the moment [value].
int malaysiaYear(DateTime value) => toMalaysiaTime(value).year;

/// Turns a date and time typed as Malaysia wall-clock time into UTC.
DateTime malaysiaWallClockToUtc(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) =>
    DateTime.utc(year, month, day, hour, minute).subtract(malaysiaOffset);

/// The UTC moment when the Malaysia calendar day containing [value] began.
DateTime malaysiaDayStartUtc(DateTime value) {
  final m = toMalaysiaTime(value);
  return DateTime.utc(m.year, m.month, m.day).subtract(malaysiaOffset);
}

/// Format: `2026-11-03`. The Malaysia calendar date of [value].
String formatMalaysiaDate(DateTime value) {
  final t = toMalaysiaTime(value);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}';
}

/// True when the Malaysia calendar date of [a] is before that of [b].
/// The time of day is ignored.
bool isMalaysiaDateBefore(DateTime a, DateTime b) =>
    malaysiaDayStartUtc(a).isBefore(malaysiaDayStartUtc(b));
