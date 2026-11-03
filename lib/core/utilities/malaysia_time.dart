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
