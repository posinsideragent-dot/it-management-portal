import '../core/utilities/malaysia_time.dart';
import '../models/daily_report.dart';

/// Report form fields that can have an error.
enum ReportFormField { date, hours, completed }

/// Rules for the report form. The UI uses it for quick feedback and the
/// service uses it again before saving.
class DailyReportValidator {
  const DailyReportValidator._();

  static const maxHours = 24.0;

  /// An empty map means the draft is valid. [nowUtc] is used to refuse a
  /// report for a day that has not started yet in Malaysia.
  static Map<ReportFormField, String> validate(
    DailyReportDraft input, {
    required DateTime nowUtc,
  }) {
    final d = input.normalized();
    final errors = <ReportFormField, String>{};

    final date = d.reportDate;
    if (date == null) {
      errors[ReportFormField.date] = 'Choose the report date.';
    } else {
      final my = toMalaysiaTime(nowUtc);
      final today = DateTime.utc(my.year, my.month, my.day);
      if (date.isAfter(today)) {
        errors[ReportFormField.date] = 'The date cannot be in the future.';
      }
    }

    final hours = d.totalHours;
    if (hours == null) {
      errors[ReportFormField.hours] = 'Enter the total hours worked.';
    } else if (hours < 0) {
      errors[ReportFormField.hours] = 'Hours cannot be negative.';
    } else if (hours > maxHours) {
      errors[ReportFormField.hours] = 'Hours cannot be more than 24.';
    }

    if (d.completedActivities.isEmpty) {
      errors[ReportFormField.completed] = 'Enter what you completed.';
    }
    return errors;
  }
}
