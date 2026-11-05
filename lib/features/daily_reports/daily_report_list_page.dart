import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/rule_violation.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/graph_client.dart';
import '../../models/daily_report.dart';
import '../../services/task_access.dart';
import '../../shared/layouts/page_frame.dart';
import '../../shared/widgets/elapsed_text.dart';
import '../../shared/widgets/status_chip.dart';
import '../../shared/widgets/table_parts.dart';
import '../../state/providers.dart';
import 'daily_report_controller.dart';
import 'daily_report_detail_dialog.dart';
import 'daily_report_form_dialog.dart';
import 'daily_report_state.dart';

/// Daily reports. Everyone writes their own. Team Leads, Management and Admin
/// can also see everyone's and review the submitted ones.
class DailyReportListPage extends ConsumerWidget {
  const DailyReportListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyReportControllerProvider);
    final user = ref.watch(currentUserProvider);
    final isLead = user != null && TaskAccess.forUser(user).isLead;
    final controller = ref.read(dailyReportControllerProvider.notifier);

    return PageFrame(
      title: 'Daily Reports',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ComboBox<String>(
                value: state.statusFilter?.label ?? _all,
                items: [
                  const ComboBoxItem<String>(
                    value: _all,
                    child: Text('All statuses'),
                  ),
                  for (final s in SubmissionStatus.values)
                    ComboBoxItem<String>(value: s.label, child: Text(s.label)),
                ],
                onChanged: (v) => controller.setStatusFilter(
                  v == null || v == _all ? null : SubmissionStatus.tryParse(v),
                ),
              ),
              if (isLead)
                ToggleSwitch(
                  checked: state.mineOnly,
                  onChanged: controller.setMineOnly,
                  content: const Text('My reports only'),
                ),
              Button(onPressed: controller.load, child: const Text('Refresh')),
              FilledButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const DailyReportFormDialog(),
                ),
                child: const Text('New report'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _Body(state: state)),
        ],
      ),
    );
  }

  static const _all = '__all__';
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final DailyReportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(dailyReportControllerProvider.notifier);

    switch (state.status) {
      case ReportLoadStatus.loading:
        return const Center(child: ProgressRing());
      case ReportLoadStatus.failed:
        return Align(
          alignment: Alignment.topLeft,
          child: InfoBar(
            title: const Text('Could not load reports'),
            content: Text(state.errorMessage ?? 'Unknown error.'),
            severity: InfoBarSeverity.error,
            isLong: true,
            action: Button(
              onPressed: controller.load,
              child: const Text('Try again'),
            ),
          ),
        );
      case ReportLoadStatus.ready:
        break;
    }

    final rows = state.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoBar(
              title: Text(state.errorMessage!),
              severity: InfoBarSeverity.warning,
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 800;
              return Column(
                children: [
                  if (wide)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: _HeaderRow(),
                    ),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('No reports found.'))
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, i) =>
                                _ReportRow(report: rows[i], wide: wide),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: state.loadingMore
                ? const ProgressRing()
                : Button(
                    onPressed: controller.loadMore,
                    child: const Text('Load more'),
                  ),
          ),
      ],
    );
  }
}

const _columns = <(String, int)>[
  ('Date', 2),
  ('Employee', 3),
  ('Hours', 1),
  ('Status', 2),
  ('Actions', 4),
];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final (title, flex) in _columns)
            TableCell2(flex: flex, child: HeaderText(title)),
        ],
      );
}

class _ReportRow extends ConsumerWidget {
  const _ReportRow({required this.report, required this.wide});

  final DailyReport report;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final names = {
      for (final e in ref.watch(activeEmployeesProvider).value ?? const [])
        e.employeeId: e.name,
    };
    final name = names[report.employeeId];
    final mine = user?.employee.employeeId == report.employeeId;
    final isLead = user != null && TaskAccess.forUser(user).isLead;
    final canEdit = mine && report.status.ownerCanEdit;
    final canReview = isLead && report.status == SubmissionStatus.submitted;
    final date = dateOnlyText(report.reportDate);
    final hours = formatMinutes(report.totalHours * 60);
    final chip = StatusChip(label: report.status.label, color: _color(report.status));

    final actions = Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Button(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => DailyReportDetailDialog(report: report, name: name),
          ),
          child: Text(canReview ? 'Review •' : 'View'),
        ),
        if (canEdit) ...[
          Button(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => DailyReportFormDialog(existing: report),
            ),
            child: const Text('Edit'),
          ),
          FilledButton(
            onPressed: () => _submit(context, ref),
            child: const Text('Submit'),
          ),
        ],
      ],
    );

    if (!wide) {
      return RowCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$date  ·  ${name ?? report.employeeId}',
                    style: FluentTheme.of(context).typography.bodyStrong,
                  ),
                ),
                chip,
              ],
            ),
            const SizedBox(height: 4),
            Text(hours),
            const SizedBox(height: 10),
            actions,
          ],
        ),
      );
    }

    Widget text(int i, String v) => TableCell2(
          flex: _columns[i].$2,
          child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
    return RowCard(
      child: Row(
        children: [
          text(0, date),
          text(1, name ?? report.employeeId),
          text(2, hours),
          TableCell2(
            flex: _columns[3].$2,
            child: Align(alignment: Alignment.centerLeft, child: chip),
          ),
          TableCell2(flex: _columns[4].$2, child: actions),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Submit report?'),
        content: Text(
          'Report ${dateOnlyText(report.reportDate)} will be sent for review '
          'and cannot be changed unless it is returned.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(dailyReportControllerProvider.notifier).submit(report);
    } on RuleViolation catch (e) {
      if (context.mounted) await _error(context, e.message);
    } on GraphException catch (e) {
      if (context.mounted) await _error(context, e.userMessage);
    }
  }

  Future<void> _error(BuildContext context, String message) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Could not save'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Color _color(SubmissionStatus s) => switch (s) {
        SubmissionStatus.draft => StatusColors.neutral,
        SubmissionStatus.submitted => StatusColors.info,
        SubmissionStatus.reviewed => StatusColors.success,
        SubmissionStatus.returned => StatusColors.warning,
      };
}
