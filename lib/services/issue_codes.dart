import 'yearly_code.dart';

/// Makes IssueCodes such as ISS-2026-00001. See [YearlyCode].
class IssueCodes {
  const IssueCodes._();

  static const _code = YearlyCode('ISS', 5);

  static String? next(String? highest, int year) => _code.next(highest, year);

  static String format(int year, int number) => _code.format(year, number);
}
