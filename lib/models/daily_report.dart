import '../core/configuration/app_config.dart';

/// IT_DailyReports SubmissionStatus choice values.
enum SubmissionStatus {
  draft('Draft'),
  submitted('Submitted'),
  reviewed('Reviewed'),
  returned('Returned');

  const SubmissionStatus(this.label);
  final String label;

  /// The owner may edit and submit in these statuses only.
  bool get ownerCanEdit =>
      this == SubmissionStatus.draft || this == SubmissionStatus.returned;

  static SubmissionStatus? tryParse(String value) {
    for (final s in SubmissionStatus.values) {
      if (s.label == value) return s;
    }
    return null;
  }
}

/// One row of the IT_DailyReports list. One report per employee per date.
class DailyReport {
  const DailyReport({
    required this.itemId,
    required this.etag,
    required this.reportCode,
    required this.employeeId,
    required this.reportDate,
    required this.completedActivities,
    required this.totalHours,
    required this.status,
    this.plannedActivities = '',
    this.pendingActivities = '',
    this.problemsEncountered = '',
    this.tomorrowPlan = '',
    this.reviewedByEmployeeId = '',
    this.reviewRemarks = '',
    this.submittedAtUtc,
    this.reviewedAtUtc,
  });

  final String itemId;

  /// Sent as If-Match on updates.
  final String etag;

  /// `DR-<EmployeeID>-<yyyyMMdd>`. Unique, so a second report for the same
  /// person and date is refused by SharePoint.
  final String reportCode;
  final String employeeId;

  /// A date without a time, held as UTC midnight of that calendar day.
  final DateTime reportDate;
  final String plannedActivities;
  final String completedActivities;
  final String pendingActivities;
  final String problemsEncountered;
  final String tomorrowPlan;
  final double totalHours;
  final SubmissionStatus status;
  final String reviewedByEmployeeId;
  final String reviewRemarks;
  final DateTime? submittedAtUtc;
  final DateTime? reviewedAtUtc;

  /// [item] is a Graph list item requested with $expand=fields.
  factory DailyReport.fromGraphItem(Map<String, dynamic> item) {
    final f = (item['fields'] as Map<String, dynamic>?) ?? const {};
    String text(String key) => (f[key] ?? '').toString();
    return DailyReport(
      itemId: item['id'].toString(),
      etag: (item['eTag'] ?? item['@odata.etag'] ?? '').toString(),
      reportCode: text(SpFields.reportCode),
      employeeId: text(SpFields.employeeId),
      reportDate: _utc(f[SpFields.reportDate]) ?? DateTime.utc(1970),
      plannedActivities: text(SpFields.plannedActivities),
      completedActivities: text(SpFields.completedActivities),
      pendingActivities: text(SpFields.pendingActivities),
      problemsEncountered: text(SpFields.problemsEncountered),
      tomorrowPlan: text(SpFields.tomorrowPlan),
      totalHours:
          f[SpFields.totalHours] is num ? (f[SpFields.totalHours] as num).toDouble() : 0,
      status: SubmissionStatus.tryParse(text(SpFields.submissionStatus)) ??
          SubmissionStatus.draft,
      reviewedByEmployeeId: text(SpFields.reviewedByEmployeeId),
      reviewRemarks: text(SpFields.reviewRemarks),
      submittedAtUtc: _utc(f[SpFields.submittedAtUtc]),
      reviewedAtUtc: _utc(f[SpFields.reviewedAtUtc]),
    );
  }
}

/// The values a person types into the report form.
class DailyReportDraft {
  const DailyReportDraft({
    required this.reportDate,
    required this.totalHours,
    required this.completedActivities,
    this.plannedActivities = '',
    this.pendingActivities = '',
    this.problemsEncountered = '',
    this.tomorrowPlan = '',
  });

  /// UTC midnight of the chosen day. Null means not chosen yet.
  final DateTime? reportDate;

  /// Null means the box is empty or not a number.
  final double? totalHours;
  final String completedActivities;
  final String plannedActivities;
  final String pendingActivities;
  final String problemsEncountered;
  final String tomorrowPlan;

  DailyReportDraft normalized() => DailyReportDraft(
        reportDate: reportDate == null
            ? null
            : DateTime.utc(reportDate!.year, reportDate!.month, reportDate!.day),
        totalHours: totalHours,
        completedActivities: completedActivities.trim(),
        plannedActivities: plannedActivities.trim(),
        pendingActivities: pendingActivities.trim(),
        problemsEncountered: problemsEncountered.trim(),
        tomorrowPlan: tomorrowPlan.trim(),
      );

  /// The text and hours. The date, code and status are set by the service.
  /// Empty optional text is sent as null to clear it.
  Map<String, Object?> toContentFields() => {
        SpFields.completedActivities: completedActivities,
        SpFields.totalHours: totalHours,
        SpFields.plannedActivities: _orNull(plannedActivities),
        SpFields.pendingActivities: _orNull(pendingActivities),
        SpFields.problemsEncountered: _orNull(problemsEncountered),
        SpFields.tomorrowPlan: _orNull(tomorrowPlan),
      };

  static String? _orNull(String v) => v.isEmpty ? null : v;
}

/// `2026-11-03T00:00:00Z`, the way a Date only column is written.
String dateOnlyIso(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}T00:00:00Z';
}

/// `2026-11-03`.
String dateOnlyText(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

DateTime? _utc(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toUtc();
