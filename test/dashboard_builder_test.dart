import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/core/utilities/malaysia_time.dart';
import 'package:it_management_portal/models/app_user.dart';
import 'package:it_management_portal/models/daily_report.dart';
import 'package:it_management_portal/models/dashboard.dart';
import 'package:it_management_portal/models/issue.dart';
import 'package:it_management_portal/models/task_enums.dart';
import 'package:it_management_portal/models/task_item.dart';
import 'package:it_management_portal/services/dashboard_builder.dart';

import 'task_service_test.dart' show emp, userOf;

// "Now" is Wed 2026-11-04 10:00 Malaysia.
final now = malaysiaWallClockToUtc(2026, 11, 4, 10);

TaskItem t(
  String code, {
  TaskStatus status = TaskStatus.inProgress,
  String assignee = 'EMP-0002',
  int dueInDays = 10,
  DocumentationStatus docs = DocumentationStatus.notRequired,
  double? proposed,
}) =>
    TaskItem(
      itemId: code,
      etag: '"1"',
      taskCode: code,
      title: 'Title $code',
      description: 'd',
      taskType: 'Bug Fix',
      assignedEmployeeId: assignee,
      createdByEmployeeId: 'EMP-0001',
      priority: TaskPriority.normal,
      status: status,
      estimatedHours: 4,
      expectedCompletion: malaysiaWallClockToUtc(2026, 11, 4 + dueInDays),
      progress: 0,
      documentationRequired: docs != DocumentationStatus.notRequired,
      documentationStatus: docs,
      proposedEstimatedHours: proposed,
    );

IssueItem issue(
  String code,
  IssueStatus status, {
  String reporter = 'EMP-0003',
  String assignee = '',
}) =>
    IssueItem(
      itemId: code,
      etag: '"1"',
      issueCode: code,
      title: 'Issue $code',
      description: 'd',
      issueType: 'Bug',
      priority: TaskPriority.normal,
      status: status,
      reportedByEmployeeId: reporter,
      assignedEmployeeId: assignee,
      reportedAtUtc: now,
    );

DailyReport report(String employee, DateTime date, SubmissionStatus status) =>
    DailyReport(
      itemId: '$employee-$date',
      etag: '"1"',
      reportCode: 'DR-$employee',
      employeeId: employee,
      reportDate: date,
      completedActivities: 'x',
      totalHours: 8,
      status: status,
    );

void main() {
  final employee = userOf(emp('2')); // EMP-0002
  final lead = userOf(emp('1', role: 'Management')); // EMP-0001
  final teamLead = userOf(emp('4', role: 'TeamLead'));

  List<String> codes(List<DashboardTask> l) =>
      l.map((e) => e.task.taskCode).toList();

  DashboardData build(
    AppUser user,
    List<TaskItem> tasks, {
    List<IssueItem> issues = const [],
    List<DailyReport> reports = const [],
    DateTime? at,
  }) =>
      DashboardBuilder.build(
        viewer: user,
        tasks: tasks,
        issues: issues,
        reports: reports,
        nowUtc: at ?? now,
      );

  group('task groups', () {
    final tasks = [
      t('A-NEW', status: TaskStatus.newTask),
      t('B-ACC', status: TaskStatus.accepted),
      t('C-DUE3', dueInDays: 3),
      t('D-DUE4', dueInDays: 4),
      t('E-DUE1', dueInDays: 1),
      t('F-TODAY', dueInDays: 0),
      t('G-LATE', dueInDays: -2),
      t('H-DONE', status: TaskStatus.completed, dueInDays: -5),
      t('I-REVIEW', status: TaskStatus.pendingReview, dueInDays: -1),
    ];

    test('pending accept is status New, start work is Accepted', () {
      final d = build(lead, tasks);
      expect(codes(d.pendingAccept), ['A-NEW']);
      expect(codes(d.startWork), ['B-ACC']);
    });

    test('almost due is 1 to 3 days ahead, soonest first', () {
      final d = build(lead, tasks);
      expect(codes(d.almostDue), ['E-DUE1', 'C-DUE3']);
    });

    test('due is today or late, latest first; finished work is left out', () {
      final d = build(lead, tasks);
      expect(codes(d.due), ['G-LATE', 'F-TODAY']);
      expect(d.due.first.isOverdue, isTrue);
      expect(d.due.last.daysToDue, 0);
    });

    test('due day counts in Malaysia time, not UTC', () {
      // 23:30 Malaysia on 4 Nov is still the 4th, though it is 15:30 UTC.
      final late = build(lead, [t('X', dueInDays: 0)],
          at: malaysiaWallClockToUtc(2026, 11, 4, 23, 30));
      expect(late.due.single.daysToDue, 0);
      // After midnight Malaysia it is one day late.
      final next = build(lead, [t('X', dueInDays: 0)],
          at: malaysiaWallClockToUtc(2026, 11, 5, 0, 5));
      expect(next.due.single.daysToDue, -1);
    });
  });

  group('who sees what', () {
    final tasks = [
      t('MINE', status: TaskStatus.newTask, assignee: 'EMP-0002'),
      t('OTHER', status: TaskStatus.newTask, assignee: 'EMP-0009'),
    ];

    test('an employee sees only their own tasks', () {
      final d = build(employee, tasks);
      expect(d.viewAll, isFalse);
      expect(codes(d.pendingAccept), ['MINE']);
    });

    test('Management, Admin and Team Lead see all tasks', () {
      expect(codes(build(lead, tasks).pendingAccept), ['MINE', 'OTHER']);
      expect(build(teamLead, tasks).viewAll, isTrue);
    });
  });

  group('notifications for a lead', () {
    test('tasks and issues that wait for review or assignment', () {
      final d = build(
        lead,
        [
          t('REVIEW', status: TaskStatus.pendingReview),
          t('REVISION', proposed: 12),
          t('DOCS', docs: DocumentationStatus.submitted),
        ],
        issues: [
          issue('ISS-OPEN', IssueStatus.open),
          issue('ISS-RES', IssueStatus.resolved),
          issue('ISS-WORK', IssueStatus.investigating),
        ],
        reports: [
          report('EMP-0002', DateTime.utc(2026, 11, 3), SubmissionStatus.submitted),
          report('EMP-0002', DateTime.utc(2026, 11, 2), SubmissionStatus.reviewed),
        ],
      );
      final titles = d.alerts.map((a) => a.title).toList();
      expect(titles, containsAll([
        'REVIEW: Title REVIEW',
        'REVISION: Title REVISION',
        'DOCS: Title DOCS',
        'ISS-OPEN: Issue ISS-OPEN',
        'ISS-RES: Issue ISS-RES',
        'Daily report 2026-11-03',
      ]));
      expect(titles.any((s) => s.contains('ISS-WORK')), isFalse);
      expect(d.alerts.every((a) => a.group == AlertGroup.toReview), isTrue);
    });

    test('an employee gets no review alerts', () {
      final d = build(
        employee,
        [t('REVIEW', status: TaskStatus.pendingReview)],
        issues: [issue('ISS-OPEN', IssueStatus.open)],
      );
      expect(d.alerts, isEmpty);
    });
  });

  group('notifications for the person', () {
    test('accept, start, documentation sent back', () {
      final d = build(employee, [
        t('NEW', status: TaskStatus.newTask),
        t('ACC', status: TaskStatus.accepted),
        t('REJ', docs: DocumentationStatus.rejected),
        t('OTHERS', status: TaskStatus.newTask, assignee: 'EMP-0009'),
      ]);
      expect(d.alerts.map((a) => a.title), [
        'NEW: Title NEW',
        'ACC: Title ACC',
        'REJ: Title REJ',
      ]);
      expect(d.alerts.every((a) => a.group == AlertGroup.yourActions), isTrue);
    });

    test('issues assigned to me, and my resolved issues to confirm', () {
      final d = build(employee, const [], issues: [
        issue('ISS-A', IssueStatus.assigned, assignee: 'EMP-0002'),
        issue('ISS-B', IssueStatus.assigned, assignee: 'EMP-0009'),
        issue('ISS-C', IssueStatus.resolved, reporter: 'EMP-0002'),
        issue('ISS-D', IssueStatus.resolved, reporter: 'EMP-0009'),
      ]);
      expect(d.alerts.map((a) => a.title), [
        'ISS-A: Issue ISS-A',
        'ISS-C: Issue ISS-C',
      ]);
    });

    test('a lead gets one alert, not two, for their own resolved issue', () {
      final d = build(lead, const [], issues: [
        issue('ISS-M', IssueStatus.resolved, reporter: 'EMP-0001'),
      ]);
      expect(d.alerts, hasLength(1));
      expect(d.alerts.single.group, AlertGroup.yourActions);
    });

    test('a returned daily report always shows', () {
      final d = build(employee, const [], reports: [
        report('EMP-0002', DateTime.utc(2026, 11, 3), SubmissionStatus.returned),
      ]);
      expect(d.alerts.single.action, contains('Returned'));
    });

    test("today's report reminder: weekday, from 16:00, none or draft", () {
      final evening = malaysiaWallClockToUtc(2026, 11, 4, 16, 30); // Wed
      final today = DateTime.utc(2026, 11, 4);
      expect(build(employee, const [], at: evening).alerts.single.action,
          contains('Not written'));
      expect(
          build(employee, const [],
                  reports: [report('EMP-0002', today, SubmissionStatus.draft)],
                  at: evening)
              .alerts
              .single
              .action,
          contains('draft'));
      expect(
          build(employee, const [],
                  reports: [report('EMP-0002', today, SubmissionStatus.submitted)],
                  at: evening)
              .alerts,
          isEmpty);
      // Before 16:00 and on a weekend there is no reminder.
      expect(build(employee, const []).alerts, isEmpty);
      final saturday = malaysiaWallClockToUtc(2026, 11, 7, 17);
      expect(build(employee, const [], at: saturday).alerts, isEmpty);
    });

    test("someone else's report never makes an alert for me", () {
      final d = build(employee, const [], reports: [
        report('EMP-0009', DateTime.utc(2026, 11, 3), SubmissionStatus.returned),
      ]);
      expect(d.alerts, isEmpty);
    });
  });
}
