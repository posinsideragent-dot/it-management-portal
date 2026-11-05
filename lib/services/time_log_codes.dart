import 'yearly_code.dart';

/// Makes TimeLogCodes such as TL-2026-000001. See [YearlyCode].
class TimeLogCodes {
  const TimeLogCodes._();

  static const _code = YearlyCode('TL', 6);

  static String? next(String? highest, int year) => _code.next(highest, year);

  static String format(int year, int number) => _code.format(year, number);
}
