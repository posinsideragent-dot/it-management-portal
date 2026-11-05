import '../core/configuration/app_config.dart';
import '../core/errors/rule_violation.dart';
import '../data/api/graph_client.dart';
import '../data/repositories/daily_report_repository.dart';
import '../models/app_user.dart';
import '../models/daily_report.dart';
import 'daily_report_validator.dart';
import 'task_access.dart';

/// A daily report rule was broken. [message] is safe to show to the user.
class DailyReportRuleException implements RuleViolation {
  DailyReportRuleException(
    this.message, {
    this.fieldErrors = const <ReportFormField, String>{},
  });

  @override
  final String message;
  final Map<ReportFormField, String> fieldErrors;

  @override
  String toString() => message;
}

/// Business rules for Daily Reports.
///
/// One report per person per day: the ReportCode is `DR-<EmployeeID>-<date>`
/// and SharePoint enforces it as unique. Employees write and submit their own
/// reports. A Team Lead, Management or Admin reviews them. A returned report
/// goes back to its owner. Reviewed reports are read-only.
///
/// Role checks are app-level (usability). SharePoint permissions are the real
/// boundary. SharePoint version history is the audit trail.
class DailyReportService {
  DailyReportService(this._reports, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final DailyReportDirectory _reports;
  final DateTime Function() _now;

  Future<DailyReportPage> listPage(
    AppUser actor, {
    bool mineOnly = true,
    String? status,
    String? nextLink,
  }) {
    // Only leads may read everyone's reports. Others always see their own.
    final all = TaskAccess.forUser(actor).isLead && !mineOnly;
    return _reports.listPage(
      employeeId: all ? null : actor.employee.employeeId,
      status: status,
      nextLink: nextLink,
    );
  }

  /// Creates the report. With [submit] it is sent for review at once.
  Future<DailyReport> create(
    AppUser actor,
    DailyReportDraft input, {
    bool submit = false,
  }) async {
    final draft = input.normalized();
    _validate(draft);
    final employeeId = actor.employee.employeeId;
    final date = draft.reportDate!;
    final now = _now().toUtc().toIso8601String();

    try {
      return await _reports.create({
        SpFields.title: 'Daily report $employeeId ${dateOnlyText(date)}',
        SpFields.reportCode: reportCodeFor(employeeId, date),
        SpFields.employeeId: employeeId,
        SpFields.reportDate: dateOnlyIso(date),
        ...draft.toContentFields(),
        SpFields.submissionStatus: (submit
                ? SubmissionStatus.submitted
                : SubmissionStatus.draft)
            .label,
        if (submit) SpFields.submittedAtUtc: now,
      });
    } on GraphException catch (e) {
      // A duplicate means nothing was created. Do not retry.
      if (e.isDuplicateValue) {
        throw DailyReportRuleException(
          'You already have a report for ${dateOnlyText(date)}. '
          'Open it from the list instead.',
          fieldErrors: {ReportFormField.date: 'A report exists for this date.'},
        );
      }
      rethrow;
    }
  }

  /// Saves changes to your own Draft or Returned report. The date cannot
  /// change. With [submit] the report is sent for review.
  Future<DailyReport> update(
    AppUser actor,
    DailyReport current,
    DailyReportDraft input, {
    bool submit = false,
  }) async {
    _requireOwnerCanEdit(actor, current);
    // The date is part of the code, so it stays as saved.
    final draft = DailyReportDraft(
      reportDate: current.reportDate,
      totalHours: input.totalHours,
      completedActivities: input.completedActivities,
      plannedActivities: input.plannedActivities,
      pendingActivities: input.pendingActivities,
      problemsEncountered: input.problemsEncountered,
      tomorrowPlan: input.tomorrowPlan,
    ).normalized();
    _validate(draft);
    return _save(current, {
      ...draft.toContentFields(),
      if (submit) ..._submitFields(),
    });
  }

  /// Sends your own Draft or Returned report for review as it is saved.
  Future<DailyReport> submit(AppUser actor, DailyReport current) async {
    _requireOwnerCanEdit(actor, current);
    // Re-check the saved values, in case the row was edited elsewhere.
    _validate(
      DailyReportDraft(
        reportDate: current.reportDate,
        totalHours: current.totalHours,
        completedActivities: current.completedActivities,
      ),
    );
    return _save(current, _submitFields());
  }

  /// A lead accepts (Reviewed) or sends back (Returned) a Submitted report.
  /// Sending back needs a reason.
  Future<DailyReport> review(
    AppUser actor,
    DailyReport current, {
    required bool accept,
    String remarks = '',
  }) async {
    if (!TaskAccess.forUser(actor).isLead) {
      throw DailyReportRuleException(
        'Only a Team Lead, Management or Admin can review reports.',
      );
    }
    if (current.status != SubmissionStatus.submitted) {
      throw DailyReportRuleException(
        'Only a Submitted report can be reviewed. This one is '
        '${current.status.label}.',
      );
    }
    final text = remarks.trim();
    if (!accept && text.isEmpty) {
      throw DailyReportRuleException('Enter the reason for sending it back.');
    }
    return _save(current, {
      SpFields.submissionStatus:
          (accept ? SubmissionStatus.reviewed : SubmissionStatus.returned).label,
      SpFields.reviewedByEmployeeId: actor.employee.employeeId,
      SpFields.reviewedAtUtc: _now().toUtc().toIso8601String(),
      SpFields.reviewRemarks: text.isEmpty ? null : text,
    });
  }

  /// `DR-EMP-0002-20261103`.
  static String reportCodeFor(String employeeId, DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'DR-$employeeId-${date.year}${two(date.month)}${two(date.day)}';
  }

  // --- helpers ---

  Map<String, Object?> _submitFields() => {
        SpFields.submissionStatus: SubmissionStatus.submitted.label,
        SpFields.submittedAtUtc: _now().toUtc().toIso8601String(),
      };

  void _requireOwnerCanEdit(AppUser actor, DailyReport current) {
    if (current.employeeId != actor.employee.employeeId) {
      throw DailyReportRuleException(
        "You can only change your own reports.",
      );
    }
    if (!current.status.ownerCanEdit) {
      throw DailyReportRuleException(
        'A ${current.status.label} report cannot be changed. '
        'Only Draft and Returned reports can.',
      );
    }
  }

  void _validate(DailyReportDraft draft) {
    final errors =
        DailyReportValidator.validate(draft, nowUtc: _now().toUtc());
    if (errors.isNotEmpty) {
      throw DailyReportRuleException(
        'Please fix the highlighted fields.',
        fieldErrors: errors,
      );
    }
  }

  Future<DailyReport> _save(
    DailyReport current,
    Map<String, Object?> fields,
  ) async {
    try {
      return await _reports.update(current: current, fields: fields);
    } on GraphException catch (e) {
      if (e.isPreconditionFailed) {
        throw DailyReportRuleException(
          'Someone else changed this report. Reload the list and try again.',
        );
      }
      rethrow;
    }
  }
}
