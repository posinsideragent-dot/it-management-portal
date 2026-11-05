import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utilities/malaysia_time.dart';
import '../../models/daily_report.dart';
import '../../services/task_access.dart';
import '../../shared/widgets/elapsed_text.dart';
import '../../state/providers.dart';
import '../task_management/task_action_dialog.dart';
import 'daily_report_controller.dart';

/// Reads one report. A lead can accept or send back a Submitted report.
class DailyReportDetailDialog extends ConsumerWidget {
  const DailyReportDetailDialog({super.key, required this.report, this.name});

  final DailyReport report;

  /// The author's name, when known.
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isLead = user != null && TaskAccess.forUser(user).isLead;
    final canReview = isLead && report.status == SubmissionStatus.submitted;
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 680),
      title: Text('Report ${dateOnlyText(report.reportDate)}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Employee', name == null ? report.employeeId : '$name (${report.employeeId})'),
            _row('Status', report.status.label),
            _row('Total hours', formatMinutes(report.totalHours * 60)),
            if (report.submittedAtUtc != null)
              _row('Submitted', formatMalaysiaTime(report.submittedAtUtc!)),
            const SizedBox(height: 8),
            _block(theme, 'Completed activities', report.completedActivities),
            _block(theme, 'Planned activities', report.plannedActivities),
            _block(theme, 'Pending activities', report.pendingActivities),
            _block(theme, 'Problems encountered', report.problemsEncountered),
            _block(theme, "Tomorrow's plan", report.tomorrowPlan),
            if (report.reviewedByEmployeeId.isNotEmpty ||
                report.reviewRemarks.isNotEmpty) ...[
              const Divider(),
              if (report.reviewedByEmployeeId.isNotEmpty)
                _row(
                  'Reviewed by',
                  '${report.reviewedByEmployeeId}'
                  '${report.reviewedAtUtc == null ? '' : ' on ${formatMalaysiaTime(report.reviewedAtUtc!)}'}',
                ),
              _block(theme, 'Review remarks', report.reviewRemarks),
            ],
            if (canReview)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => _review(context, ref, accept: true),
                      child: const Text('Accept report'),
                    ),
                    Button(
                      onPressed: () => _review(context, ref, accept: false),
                      child: const Text('Send back'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref, {
    required bool accept,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => TaskActionDialog(
        title: accept ? 'Accept report' : 'Send report back',
        summary: 'Report ${dateOnlyText(report.reportDate)} by '
            '${report.employeeId}.',
        textLabel: accept ? 'Remarks (optional)' : 'Reason for sending back',
        confirmLabel: accept ? 'Accept' : 'Send back',
        onConfirm: (i) => ref
            .read(dailyReportControllerProvider.notifier)
            .review(report, accept: accept, remarks: i.text),
      ),
    );
    // The row on this screen is old now. Close it so the list shows the new one.
    if (saved == true && context.mounted) Navigator.pop(context);
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: Text(label)),
            Expanded(child: SelectableText(value.isEmpty ? '-' : value)),
          ],
        ),
      );

  Widget _block(FluentThemeData theme, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.typography.bodyStrong),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}
