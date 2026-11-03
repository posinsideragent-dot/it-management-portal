import 'package:flutter_test/flutter_test.dart';
import 'package:it_management_portal/data/api/graph_client.dart';
import 'package:it_management_portal/data/repositories/daily_report_repository.dart';
import 'package:it_management_portal/models/app_user.dart';
import 'package:it_management_portal/models/daily_report.dart';
import 'package:it_management_portal/services/daily_report_service.dart';
import 'package:it_management_portal/services/daily_report_validator.dart';

import 'task_service_test.dart' show emp, userOf;

DailyReport report({
  SubmissionStatus status = SubmissionStatus.draft,
  String employee = 'EMP-0002',
  String completed = 'Fixed bugs',
  double hours = 8,
}) =>
    DailyReport(
      itemId: '5',
      etag: '"5,1"',
      reportCode: 'DR-$employee-20261103',
      employeeId: employee,
      reportDate: DateTime.utc(2026, 11, 3),
      completedActivities: completed,
      totalHours: hours,
      status: status,
    );

DailyReportDraft draft({
  DateTime? date,
  double? hours = 8,
  String completed = 'Fixed bugs',
  String tomorrow = '',
}) =>
    DailyReportDraft(
      reportDate: date ?? DateTime.utc(2026, 11, 3),
      totalHours: hours,
      completedActivities: completed,
      tomorrowPlan: tomorrow,
    );

class FakeReports implements DailyReportDirectory {
  final createCalls = <Map<String, Object?>>[];
  final updateCalls = <Map<String, Object?>>[];
  final listCalls = <Map<String, String?>>[];
  GraphException? createError;
  GraphException? updateError;

  @override
  Future<DailyReportPage> listPage({
    String? employeeId,
    String? status,
    String? nextLink,
  }) async {
    listCalls.add({'employeeId': employeeId, 'status': status});
    return const DailyReportPage(items: []);
  }

  @override
  Future<DailyReport> create(Map<String, Object?> fields) async {
    createCalls.add(fields);
    if (createError != null) throw createError!;
    return report();
  }

  @override
  Future<DailyReport> update({
    required DailyReport current,
    required Map<String, Object?> fields,
  }) async {
    updateCalls.add(fields);
    if (updateError != null) throw updateError!;
    return current;
  }
}

void main() {
  late FakeReports reports;
  late DailyReportService service;
  late AppUser worker; // EMP-0002
  late AppUser other; // EMP-0003
  late AppUser lead; // EMP-0001, Team Lead

  setUp(() {
    reports = FakeReports();
    worker = userOf(emp('2'));
    other = userOf(emp('3'));
    lead = userOf(emp('1', role: 'TeamLead'));
    // 2026-11-03 11:00 Malaysia
    service = DailyReportService(reports, clock: () => DateTime.utc(2026, 11, 3, 3));
  });

  Future<DailyReportRuleException> ruleError(
    Future<Object?> Function() run,
  ) async {
    try {
      await run();
    } on DailyReportRuleException catch (e) {
      return e;
    }
    fail('Expected a DailyReportRuleException');
  }

  group('validator', () {
    final now = DateTime.utc(2026, 11, 3, 3);

    test('a good draft has no errors', () {
      expect(DailyReportValidator.validate(draft(), nowUtc: now), isEmpty);
    });

    test('hours must be 0 to 24', () {
      for (final h in <double?>[null, -1, 24.5]) {
        expect(
          DailyReportValidator.validate(draft(hours: h), nowUtc: now),
          contains(ReportFormField.hours),
        );
      }
      expect(DailyReportValidator.validate(draft(hours: 0), nowUtc: now), isEmpty);
      expect(DailyReportValidator.validate(draft(hours: 24), nowUtc: now), isEmpty);
    });

    test('completed activities are required', () {
      expect(
        DailyReportValidator.validate(draft(completed: '  '), nowUtc: now),
        contains(ReportFormField.completed),
      );
    });

    test('the date cannot be in the future (Malaysia day)', () {
      // 23:30 UTC on 3 Nov is already 4 Nov in Malaysia.
      final late = DateTime.utc(2026, 11, 3, 23, 30);
      expect(
        DailyReportValidator.validate(
          draft(date: DateTime.utc(2026, 11, 4)),
          nowUtc: late,
        ),
        isEmpty,
      );
      expect(
        DailyReportValidator.validate(
          draft(date: DateTime.utc(2026, 11, 4)),
          nowUtc: now,
        ),
        contains(ReportFormField.date),
      );
      expect(
        DailyReportValidator.validate(
          DailyReportDraft(
            reportDate: null,
            totalHours: 1,
            completedActivities: 'x',
          ),
          nowUtc: now,
        ),
        contains(ReportFormField.date),
      );
    });
  });

  group('create', () {
    test('saves a draft with the per-day code', () async {
      await service.create(worker, draft(tomorrow: ' Test it '));
      final f = reports.createCalls.single;
      expect(f['ReportCode'], 'DR-EMP-0002-20261103');
      expect(f['EmployeeID'], 'EMP-0002');
      expect(f['ReportDate'], '2026-11-03T00:00:00Z');
      expect(f['SubmissionStatus'], 'Draft');
      expect(f['TotalHours'], 8);
      expect(f['TomorrowPlan'], 'Test it');
      expect(f['PlannedActivities'], isNull);
      expect(f.containsKey('SubmittedAtUTC'), isFalse);
    });

    test('create and submit sets the status and time', () async {
      await service.create(worker, draft(), submit: true);
      final f = reports.createCalls.single;
      expect(f['SubmissionStatus'], 'Submitted');
      expect(f['SubmittedAtUTC'], '2026-11-03T03:00:00.000Z');
    });

    test('an invalid draft is refused before saving', () async {
      final e = await ruleError(
        () => service.create(worker, draft(hours: null)),
      );
      expect(e.fieldErrors, contains(ReportFormField.hours));
      expect(reports.createCalls, isEmpty);
    });

    test('a second report for the same day is explained, not retried',
        () async {
      reports.createError =
          GraphException(statusCode: 409, userMessage: 'duplicate');
      final e = await ruleError(() => service.create(worker, draft()));
      expect(e.message, contains('already have a report'));
      expect(e.fieldErrors, contains(ReportFormField.date));
      expect(reports.createCalls, hasLength(1));
    });

    test('other errors pass through', () async {
      reports.createError =
          GraphException(statusCode: 500, userMessage: 'server');
      await expectLater(
        service.create(worker, draft()),
        throwsA(isA<GraphException>()),
      );
    });
  });

  group('update and submit', () {
    test('the owner edits a draft; the date stays', () async {
      await service.update(
        worker,
        report(),
        draft(date: DateTime.utc(2026, 11, 1), hours: 7),
      );
      final f = reports.updateCalls.single;
      expect(f['TotalHours'], 7);
      expect(f.containsKey('ReportDate'), isFalse);
      expect(f.containsKey('SubmissionStatus'), isFalse);
    });

    test('save and submit on a returned report', () async {
      await service.update(
        worker,
        report(status: SubmissionStatus.returned),
        draft(),
        submit: true,
      );
      final f = reports.updateCalls.single;
      expect(f['SubmissionStatus'], 'Submitted');
      expect(f['SubmittedAtUTC'], '2026-11-03T03:00:00.000Z');
    });

    test('only the owner may change it', () async {
      final e = await ruleError(() => service.update(other, report(), draft()));
      expect(e.message, contains('your own'));
      await ruleError(() => service.update(lead, report(), draft()));
      await ruleError(() => service.submit(other, report()));
      expect(reports.updateCalls, isEmpty);
    });

    test('Submitted and Reviewed reports are read-only', () async {
      for (final s in [SubmissionStatus.submitted, SubmissionStatus.reviewed]) {
        await ruleError(() => service.update(worker, report(status: s), draft()));
        await ruleError(() => service.submit(worker, report(status: s)));
      }
      expect(reports.updateCalls, isEmpty);
    });

    test('submit sends the saved draft for review', () async {
      await service.submit(worker, report());
      final f = reports.updateCalls.single;
      expect(f['SubmissionStatus'], 'Submitted');
    });

    test('submit re-checks the saved values', () async {
      await ruleError(() => service.submit(worker, report(completed: '')));
      expect(reports.updateCalls, isEmpty);
    });

    test('a stale ETag gives a clear message', () async {
      reports.updateError =
          GraphException(statusCode: 412, userMessage: 'precondition');
      final e = await ruleError(() => service.submit(worker, report()));
      expect(e.message, contains('Someone else'));
    });
  });

  group('review', () {
    final submitted = report(status: SubmissionStatus.submitted);

    test('a lead accepts', () async {
      await service.review(lead, submitted, accept: true);
      final f = reports.updateCalls.single;
      expect(f['SubmissionStatus'], 'Reviewed');
      expect(f['ReviewedByEmployeeID'], 'EMP-0001');
      expect(f['ReviewedAtUTC'], '2026-11-03T03:00:00.000Z');
      expect(f['ReviewRemarks'], isNull);
    });

    test('sending back needs a reason', () async {
      await ruleError(() => service.review(lead, submitted, accept: false));
      await service.review(
        lead,
        submitted,
        accept: false,
        remarks: ' Add hours detail ',
      );
      final f = reports.updateCalls.single;
      expect(f['SubmissionStatus'], 'Returned');
      expect(f['ReviewRemarks'], 'Add hours detail');
    });

    test('an Employee cannot review', () async {
      final e = await ruleError(
        () => service.review(worker, submitted, accept: true),
      );
      expect(e.message, contains('Team Lead'));
      expect(reports.updateCalls, isEmpty);
    });

    test('only Submitted reports are reviewed', () async {
      for (final s in [
        SubmissionStatus.draft,
        SubmissionStatus.reviewed,
        SubmissionStatus.returned,
      ]) {
        await ruleError(
          () => service.review(lead, report(status: s), accept: true),
        );
      }
      expect(reports.updateCalls, isEmpty);
    });
  });

  group('listing', () {
    test('an Employee always sees only their own reports', () async {
      await service.listPage(worker, mineOnly: false);
      expect(reports.listCalls.single['employeeId'], 'EMP-0002');
    });

    test('a lead can see everyone, or only their own', () async {
      await service.listPage(lead, mineOnly: false, status: 'Submitted');
      expect(reports.listCalls.last['employeeId'], isNull);
      expect(reports.listCalls.last['status'], 'Submitted');
      await service.listPage(lead);
      expect(reports.listCalls.last['employeeId'], 'EMP-0001');
    });
  });

  test('report code format', () {
    expect(
      DailyReportService.reportCodeFor('EMP-0007', DateTime.utc(2026, 1, 5)),
      'DR-EMP-0007-20260105',
    );
  });
}
