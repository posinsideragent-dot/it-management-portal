import '../core/utilities/malaysia_time.dart';
import '../models/app_user.dart';
import '../models/daily_report.dart';
import '../models/dashboard.dart';
import '../models/issue.dart';
import '../models/task_enums.dart';
import '../models/task_item.dart';
import 'task_access.dart';

/// Turns loaded rows into the dashboard. Pure code with no network, so it is
/// easy to test. The rules for what "needs action" are all here.
///
/// App-level scoping is for usability. SharePoint permissions are the real
/// security.
class DashboardBuilder {
  const DashboardBuilder._();

  /// Tasks due within this many days (1 to 3) are "almost due".
  static const almostDueDays = 3;

  /// From this Malaysia hour on a weekday, a missing daily report is an alert.
  static const reportReminderHour = 16;

  /// [tasks] are the tasks the viewer may see here: all open tasks for a lead
  /// view, or the viewer's own for an employee. [issues] are the issues that
  /// are assigned to the viewer, Open, or Resolved. [reports] are the viewer's
  /// own recent reports plus, for a lead, the Submitted ones of everyone.
  static DashboardData build({
    required AppUser viewer,
    required List<TaskItem> tasks,
    required List<IssueItem> issues,
    required List<DailyReport> reports,
    required DateTime nowUtc,
    bool truncated = false,
  }) {
    final me = viewer.employee.employeeId;
    final isLead = TaskAccess.forUser(viewer).isLead;
    // An employee sees only their own tasks, whatever was loaded.
    final scoped = tasks
        .where((t) => !t.status.isFinal)
        .where((t) => isLead || t.assignedEmployeeId == me)
        .toList();

    final today = malaysiaDayStartUtc(nowUtc);
    int daysTo(TaskItem t) =>
        malaysiaDayStartUtc(t.expectedCompletion).difference(today).inDays;
    DashboardTask wrap(TaskItem t) =>
        DashboardTask(task: t, daysToDue: daysTo(t));
    int byDue(DashboardTask a, DashboardTask b) {
      final c = a.daysToDue.compareTo(b.daysToDue);
      return c != 0 ? c : a.task.taskCode.compareTo(b.task.taskCode);
    }

    // Work that is already finished (Pending Review) is not "due".
    final running = scoped
        .where((t) => t.status != TaskStatus.pendingReview)
        .map(wrap)
        .toList();

    List<DashboardTask> withStatus(TaskStatus s) =>
        (scoped.where((t) => t.status == s).map(wrap).toList())..sort(byDue);

    final almost = running
        .where((t) => t.daysToDue >= 1 && t.daysToDue <= almostDueDays)
        .toList()
      ..sort(byDue);
    final due = running.where((t) => t.daysToDue <= 0).toList()..sort(byDue);

    return DashboardData(
      viewAll: isLead,
      pendingAccept: withStatus(TaskStatus.newTask),
      startWork: withStatus(TaskStatus.accepted),
      almostDue: almost,
      due: due,
      alerts: _alerts(
        me: me,
        isLead: isLead,
        tasks: scoped,
        issues: issues,
        reports: reports,
        nowUtc: nowUtc,
      ),
      loadedAtUtc: nowUtc,
      truncated: truncated,
    );
  }

  static List<DashboardAlert> _alerts({
    required String me,
    required bool isLead,
    required List<TaskItem> tasks,
    required List<IssueItem> issues,
    required List<DailyReport> reports,
    required DateTime nowUtc,
  }) {
    final review = <DashboardAlert>[];
    final mine = <DashboardAlert>[];

    String taskTitle(TaskItem t) => '${t.taskCode}: ${t.title}';
    String issueTitle(IssueItem i) => '${i.issueCode}: ${i.title}';

    for (final t in tasks) {
      if (isLead) {
        if (t.status == TaskStatus.pendingReview) {
          review.add(DashboardAlert(
            group: AlertGroup.toReview,
            target: AlertTarget.tasks,
            title: taskTitle(t),
            action: 'Submitted for review. Approve or send back.',
            employeeId: t.assignedEmployeeId,
          ));
        }
        if (t.hasPendingRevision) {
          review.add(DashboardAlert(
            group: AlertGroup.toReview,
            target: AlertTarget.tasks,
            title: taskTitle(t),
            action: 'Estimate revision to approve '
                '(${_hours(t.proposedEstimatedHours!)} h).',
            employeeId: t.assignedEmployeeId,
          ));
        }
        if (t.documentationRequired &&
            t.documentationStatus == DocumentationStatus.submitted) {
          review.add(DashboardAlert(
            group: AlertGroup.toReview,
            target: AlertTarget.tasks,
            title: taskTitle(t),
            action: 'Documentation submitted. Review it.',
            employeeId: t.assignedEmployeeId,
          ));
        }
      }
      if (t.assignedEmployeeId == me) {
        if (t.status == TaskStatus.newTask) {
          mine.add(_mineTask(t, 'New task. Accept it.'));
        } else if (t.status == TaskStatus.accepted) {
          mine.add(_mineTask(t, 'Accepted. Start the work.'));
        }
        if (t.documentationRequired &&
            t.documentationStatus == DocumentationStatus.rejected) {
          mine.add(_mineTask(
            t,
            'Documentation sent back. Fix and submit again.',
          ));
        }
      }
    }

    for (final i in issues) {
      if (i.status == IssueStatus.assigned && i.assignedEmployeeId == me) {
        mine.add(DashboardAlert(
          group: AlertGroup.yourActions,
          target: AlertTarget.issues,
          title: issueTitle(i),
          action: 'Assigned to you. Start investigating.',
        ));
      }
      if (i.status == IssueStatus.resolved && i.reportedByEmployeeId == me) {
        mine.add(DashboardAlert(
          group: AlertGroup.yourActions,
          target: AlertTarget.issues,
          title: issueTitle(i),
          action: 'Marked resolved. Confirm it or reopen.',
        ));
      }
      if (isLead) {
        if (i.status == IssueStatus.open) {
          review.add(DashboardAlert(
            group: AlertGroup.toReview,
            target: AlertTarget.issues,
            title: issueTitle(i),
            action: 'New issue. Assign it to someone.',
            employeeId: i.reportedByEmployeeId,
          ));
        } else if (i.status == IssueStatus.resolved &&
            i.reportedByEmployeeId != me) {
          review.add(DashboardAlert(
            group: AlertGroup.toReview,
            target: AlertTarget.issues,
            title: issueTitle(i),
            action: 'Marked resolved. Confirm it or reopen.',
            employeeId: i.reportedByEmployeeId,
          ));
        }
      }
    }

    final my = toMalaysiaTime(nowUtc);
    final todayDate = DateTime.utc(my.year, my.month, my.day);
    DailyReport? todays;
    for (final r in reports) {
      if (r.employeeId != me) continue;
      if (r.reportDate == todayDate) todays = r;
      if (r.status == SubmissionStatus.returned) {
        mine.add(DashboardAlert(
          group: AlertGroup.yourActions,
          target: AlertTarget.dailyReports,
          title: 'Daily report ${formatMalaysiaDate(r.reportDate)}',
          action: 'Returned. Fix it and submit again.',
        ));
      }
    }
    final isWeekday = my.weekday <= DateTime.friday;
    if (isWeekday && my.hour >= reportReminderHour) {
      if (todays == null) {
        mine.add(const DashboardAlert(
          group: AlertGroup.yourActions,
          target: AlertTarget.dailyReports,
          title: "Today's daily report",
          action: 'Not written yet. Write and submit it.',
        ));
      } else if (todays.status == SubmissionStatus.draft) {
        mine.add(const DashboardAlert(
          group: AlertGroup.yourActions,
          target: AlertTarget.dailyReports,
          title: "Today's daily report",
          action: 'Still a draft. Submit it.',
        ));
      }
    }

    if (isLead) {
      for (final r in reports) {
        if (r.status == SubmissionStatus.submitted) {
          review.add(DashboardAlert(
            group: AlertGroup.toReview,
            target: AlertTarget.dailyReports,
            title: 'Daily report ${formatMalaysiaDate(r.reportDate)}',
            action: 'Submitted. Accept it or send it back.',
            employeeId: r.employeeId,
          ));
        }
      }
    }

    return [...review, ...mine];
  }

  static DashboardAlert _mineTask(TaskItem t, String action) => DashboardAlert(
        group: AlertGroup.yourActions,
        target: AlertTarget.tasks,
        title: '${t.taskCode}: ${t.title}',
        action: action,
      );

  static String _hours(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
