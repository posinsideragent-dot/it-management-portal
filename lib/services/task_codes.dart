import 'yearly_code.dart';

/// Makes TaskCodes such as TASK-2026-00001. See [YearlyCode].
class TaskCodes {
  const TaskCodes._();

  static const _code = YearlyCode('TASK', 5);

  static String? next(String? highest, int year) => _code.next(highest, year);

  static String format(int year, int number) => _code.format(year, number);
}
