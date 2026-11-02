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
}
