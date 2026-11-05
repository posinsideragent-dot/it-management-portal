import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/malaysia_time.dart';
import '../../data/api/graph_client.dart';
import '../../models/daily_report.dart';
import '../../services/daily_report_service.dart';
import '../../services/daily_report_validator.dart';
import 'daily_report_controller.dart';

/// Create or edit one daily report. Pops `true` when it was saved.
/// Only form state lives here. The rules are in [DailyReportService].
class DailyReportFormDialog extends ConsumerStatefulWidget {
  const DailyReportFormDialog({super.key, this.existing});

  /// Null means create a new report.
  final DailyReport? existing;

  @override
  ConsumerState<DailyReportFormDialog> createState() =>
      _DailyReportFormDialogState();
}

class _DailyReportFormDialogState extends ConsumerState<DailyReportFormDialog> {
  late final TextEditingController _hours;
  late final TextEditingController _completed;
  late final TextEditingController _planned;
  late final TextEditingController _pending;
  late final TextEditingController _problems;
  late final TextEditingController _tomorrow;
  late DateTime _date;

  Map<ReportFormField, String> _errors = const {};
  String? _message;
  bool _saving = false;

  bool get _isCreate => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    final my = toMalaysiaTime(DateTime.now());
    _date = r?.reportDate ?? DateTime.utc(my.year, my.month, my.day);
    _hours = TextEditingController(
      text: r == null ? '' : _fmt(r.totalHours),
    );
    _completed = TextEditingController(text: r?.completedActivities ?? '');
    _planned = TextEditingController(text: r?.plannedActivities ?? '');
    _pending = TextEditingController(text: r?.pendingActivities ?? '');
    _problems = TextEditingController(text: r?.problemsEncountered ?? '');
    _tomorrow = TextEditingController(text: r?.tomorrowPlan ?? '');
  }

  @override
  void dispose() {
    for (final c in [_hours, _completed, _planned, _pending, _problems, _tomorrow]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

  DailyReportDraft _draft() => DailyReportDraft(
        reportDate: _date,
        totalHours: double.tryParse(_hours.text.trim()),
        completedActivities: _completed.text,
        plannedActivities: _planned.text,
        pendingActivities: _pending.text,
        problemsEncountered: _problems.text,
        tomorrowPlan: _tomorrow.text,
      );

  Future<void> _save({required bool submit}) async {
    final draft = _draft();
    final errors = DailyReportValidator.validate(
      draft,
      nowUtc: DateTime.now().toUtc(),
    );
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _message = 'Please fix the highlighted fields.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _errors = const {};
      _message = null;
    });
    final controller = ref.read(dailyReportControllerProvider.notifier);
    try {
      if (_isCreate) {
        await controller.create(draft, submit: submit);
      } else {
        await controller.edit(widget.existing!, draft, submit: submit);
      }
      if (mounted) Navigator.pop(context, true);
    } on DailyReportRuleException catch (e) {
      if (mounted) {
        setState(() {
          _errors = e.fieldErrors;
          _message = e.message;
        });
      }
    } on GraphException catch (e) {
      if (mounted) setState(() => _message = e.userMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, Widget child, [ReportFormField? field]) {
    final error = field == null ? null : _errors[field];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoLabel(
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child,
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: const TextStyle(color: StatusColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _text(TextEditingController c, {int lines = 3}) =>
      TextBox(controller: c, enabled: !_saving, minLines: lines, maxLines: 6);

  @override
  Widget build(BuildContext context) {
    final returned = widget.existing?.reviewRemarks ?? '';
    return ContentDialog(
      title: Text(
        _isCreate
            ? 'New daily report'
            : 'Edit report ${dateOnlyText(widget.existing!.reportDate)}',
      ),
      constraints: const BoxConstraints(maxWidth: 600),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_message != null) ...[
              InfoBar(title: Text(_message!), severity: InfoBarSeverity.error),
              const SizedBox(height: 12),
            ],
            if (!_isCreate && returned.isNotEmpty) ...[
              InfoBar(
                title: const Text('Returned by the reviewer'),
                content: Text(returned),
                severity: InfoBarSeverity.warning,
                isLong: true,
              ),
              const SizedBox(height: 12),
            ],
            _field(
              'Report date',
              _isCreate
                  ? DatePicker(
                      selected: DateTime(_date.year, _date.month, _date.day),
                      onChanged: _saving
                          ? null
                          : (d) => setState(
                                () => _date = DateTime.utc(d.year, d.month, d.day),
                              ),
                    )
                  : Text('${dateOnlyText(_date)} (cannot be changed)'),
              ReportFormField.date,
            ),
            _field(
              'Total hours worked (0 to 24)',
              TextBox(controller: _hours, enabled: !_saving),
              ReportFormField.hours,
            ),
            _field(
              'Completed activities',
              _text(_completed),
              ReportFormField.completed,
            ),
            _field('Planned activities (optional)', _text(_planned, lines: 2)),
            _field('Pending activities (optional)', _text(_pending, lines: 2)),
            _field('Problems encountered (optional)', _text(_problems, lines: 2)),
            _field("Tomorrow's plan (optional)", _text(_tomorrow, lines: 2)),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        Button(
          onPressed: _saving ? null : () => _save(submit: false),
          child: const Text('Save draft'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(submit: true),
          child: const Text('Save and submit'),
        ),
      ],
    );
  }
}
