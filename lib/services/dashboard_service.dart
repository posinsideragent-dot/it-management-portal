import '../data/repositories/daily_report_repository.dart';
import '../data/repositories/issue_repository.dart';
import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/daily_report.dart';
import '../models/dashboard.dart';
import '../models/issue.dart';
import '../models/task_enums.dart';
import '../models/task_item.dart';
import 'dashboard_builder.dart';
import 'task_access.dart';

/// Loads the rows the dashboard needs, then hands them to
/// [DashboardBuilder]. Reads only. Every query uses an indexed column
/// (Status, AssignedEmployeeID, EmployeeID) and follows paging.
class DashboardService {
  DashboardService(
    this._tasks,
    this._issues,
    this._reports, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TaskDirectory _tasks;
  final IssueDirectory _issues;
  final DailyReportDirectory _reports;
  final DateTime Function() _now;

  /// At most this many pages per query (25 rows each). Past that the
  /// dashboard says the numbers may be low.
  static const maxPages = 8;

  static const _openStatuses = [
    TaskStatus.newTask,
    TaskStatus.accepted,
    TaskStatus.inProgress,
    TaskStatus.onHold,
    TaskStatus.pendingReview,
  ];

  Future<DashboardData> load(AppUser viewer) async {
    final me = viewer.employee.employeeId;
    final isLead = TaskAccess.forUser(viewer).isLead;
    var truncated = false;

    Future<List<T>> drain<T>(
      Future<(List<T>, String?)> Function(String? nextLink) fetch,
    ) async {
      final all = <T>[];
      String? next;
      for (var page = 0; page < maxPages; page++) {
        final (items, link) = await fetch(next);
        all.addAll(items);
        if (link == null) return all;
        next = link;
      }
      truncated = true;
      return all;
    }

    Future<List<TaskItem>> tasksWhere({
      String? status,
      String? assignee,
    }) =>
        drain<TaskItem>((next) async {
          final p = await _tasks.listPage(
            status: status,
            assignedEmployeeId: assignee,
            nextLink: next,
          );
          return (p.items, p.nextLink);
        });

    Future<List<IssueItem>> issuesWhere({
      String? status,
      String? assignee,
    }) =>
        drain<IssueItem>((next) async {
          final p = await _issues.listPage(
            status: status,
            assignedEmployeeId: assignee,
            nextLink: next,
          );
          return (p.items, p.nextLink);
        });

    Future<List<DailyReport>> reportsWhere({
      String? employeeId,
      String? status,
    }) =>
        drain<DailyReport>((next) async {
          final p = await _reports.listPage(
            employeeId: employeeId,
            status: status,
            nextLink: next,
          );
          return (p.items, p.nextLink);
        });

    final taskLoad = isLead
        ? Future.wait(
            _openStatuses.map((s) => tasksWhere(status: s.label)),
          ).then((lists) => [for (final l in lists) ...l])
        : tasksWhere(assignee: me);

    final results = await Future.wait<Object>([
      taskLoad,
      issuesWhere(status: IssueStatus.assigned.label, assignee: me),
      issuesWhere(status: IssueStatus.resolved.label),
      if (isLead) issuesWhere(status: IssueStatus.open.label),
      // Only the first page (newest first) of the viewer's own reports.
      _reports.listPage(employeeId: me).then((p) => p.items),
      if (isLead) reportsWhere(status: SubmissionStatus.submitted.label),
    ]);

    var i = 0;
    final tasks = results[i++] as List<TaskItem>;
    final assigned = results[i++] as List<IssueItem>;
    final resolved = results[i++] as List<IssueItem>;
    final open = isLead ? results[i++] as List<IssueItem> : <IssueItem>[];
    final mine = results[i++] as List<DailyReport>;
    final submitted =
        isLead ? results[i++] as List<DailyReport> : <DailyReport>[];

    // The same issue can come from two queries. Keep one of each.
    final issues = {
      for (final x in [...assigned, ...resolved, ...open]) x.itemId: x,
    }.values.toList();
    final reports = {
      for (final x in [...mine, ...submitted]) x.itemId: x,
    }.values.toList();

    return DashboardBuilder.build(
      viewer: viewer,
      tasks: tasks,
      issues: issues,
      reports: reports,
      nowUtc: _now().toUtc(),
      truncated: truncated,
    );
  }
}
