import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/core/utilities/malaysia_time.dart';

void main() {
  test('UTC is shown as UTC+8', () {
    final utc = DateTime.utc(2026, 11, 3, 6, 5);
    expect(formatMalaysiaTime(utc), '2026-11-03 14:05');
  });

  test('crossing midnight moves to the next day', () {
    final utc = DateTime.utc(2026, 12, 31, 20, 0);
    expect(formatMalaysiaTime(utc), '2027-01-01 04:00');
  });

  group('Malaysia dates', () {
    test('formatMalaysiaDate uses the Malaysia day', () {
      // 2026-11-03 17:00 UTC is 2026-11-04 01:00 Malaysia.
      expect(formatMalaysiaDate(DateTime.utc(2026, 11, 3, 17)), '2026-11-04');
      expect(formatMalaysiaDate(malaysiaWallClockToUtc(2026, 11, 5)), '2026-11-05');
    });
    test('isMalaysiaDateBefore ignores the time of day', () {
      final morning = malaysiaWallClockToUtc(2026, 11, 3, 8);
      final night = malaysiaWallClockToUtc(2026, 11, 3, 23, 59);
      final next = malaysiaWallClockToUtc(2026, 11, 4, 0, 1);
      expect(isMalaysiaDateBefore(morning, night), isFalse);
      expect(isMalaysiaDateBefore(night, next), isTrue);
    });
  });
}
