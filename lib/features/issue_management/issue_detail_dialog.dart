import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/rule_violation.dart';
import '../../core/utilities/malaysia_time.dart';
import '../../data/api/graph_client.dart';
import '../../models/employee.dart';
import '../../models/issue.dart';
import '../../services/issue_workflow.dart';
import '../../services/task_access.dart';
import '../../state/providers.dart';
import '../task_management/task_action_dialog.dart';
import 'issue_form_dialog.dart';
import 'issue_list_controller.dart';

/// Everything about one issue, with the actions the person is allowed.
/// It follows the list, so it shows the saved values after an action.
class IssueDetailDialog extends ConsumerWidget {
  const IssueDetailDialog({super.key, required this.initial});

  final IssueItem initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(issueListControllerProvider).items;
    final issue = items.firstWhere(
      (i) => i.itemId == initial.itemId,
      orElse: () => initial,
    );
    final user = ref.watch(currentUserProvider);
    final actors =
        user == null ? <IssueActor>{} : IssueAccess.actorsFor(user, issue);
    final isLead = user != null && TaskAccess.forUser(user).isLead;
    final moves = IssueWorkflow.movesFor(issue.status, actors);
    final canEdit = !issue.status.isFinal &&
        (isLead ||
            (actors.contains(IssueActor.reporter) &&
                issue.status == IssueStatus.open));
    final canAssign = isLead &&
        const {
          IssueStatus.open,
          IssueStatus.assigned,
          IssueStatus.investigating,
          IssueStatus.waiting,
        }.contains(issue.status);
    final names = {
      for (final e in ref.watch(activeEmployeesProvider).value ?? const <Employee>[])
        e.employeeId: e.name,
    };
    String who(String id) =>
        id.isEmpty ? '-' : (names[id] == null ? id : '${names[id]} ($id)');

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 680),
      title: Text('${issue.issueCode}: ${issue.title}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Status', issue.status.label),
            _row('Type', issue.issueType),
            _row('Priority', issue.priority.label),
            _row('Reported by', who(issue.reportedByEmployeeId)),
            _row('Reported', formatMalaysiaTime(issue.reportedAtUtc)),
            _row('Assigned to', who(issue.assignedEmployeeId)),
            if (issue.relatedTaskCode.isNotEmpty)
              _row('Related task', issue.relatedTaskCode),
            if (issue.projectCode.isNotEmpty) _row('Project', issue.projectCode),
            _row('Description', issue.description),
            if (issue.resolutionRemarks.isNotEmpty)
              _row('Latest note', issue.resolutionRemarks),
            if (issue.resolvedAtUtc != null)
              _row('Resolved', formatMalaysiaTime(issue.resolvedAtUtc!)),
            if (canEdit || canAssign || moves.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final move in moves)
                      FilledButton(
                        onPressed: () => _move(context, ref, issue, move),
                        child: Text(move.label),
                      ),
                    if (canAssign)
                      Button(
                        onPressed: () => _assign(context, ref, issue),
                        child: Text(
                          issue.assignedEmployeeId.isEmpty ? 'Assign' : 'Reassign',
                        ),
                      ),
                    if (canEdit)
                      Button(
                        onPressed: () => showDialog<bool>(
                          context: context,
                          builder: (_) => IssueFormDialog(existing: issue),
                        ),
                        child: const Text('Edit'),
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

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    IssueItem issue,
    IssueMove move,
  ) =>
      showDialog<bool>(
        context: context,
        builder: (_) => TaskActionDialog(
          title: move.label,
          summary: '${issue.issueCode}: ${move.from.label} to ${move.to.label}',
          textLabel: move.remarksLabel,
          confirmLabel: move.label,
          onConfirm: (i) => ref
              .read(issueListControllerProvider.notifier)
              .changeStatus(issue, move.to, remarks: i.text),
        ),
      );

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    IssueItem issue,
  ) =>
      showDialog<bool>(
        context: context,
        builder: (_) => _AssignDialog(issue: issue),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 130, child: Text(label)),
            Expanded(child: SelectableText(value.isEmpty ? '-' : value)),
          ],
        ),
      );
}

/// Chooses who the issue is assigned to.
class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.issue});

  final IssueItem issue;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  String? _employee;
  String? _message;
  bool _saving = false;

  Future<void> _save() async {
    final id = _employee;
    if (id == null) {
      setState(() => _message = 'Choose who to assign it to.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref
          .read(issueListControllerProvider.notifier)
          .assign(widget.issue, id);
      if (mounted) Navigator.pop(context, true);
    } on RuleViolation catch (e) {
      if (mounted) setState(() => _message = e.message);
    } on GraphException catch (e) {
      if (mounted) setState(() => _message = e.userMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(activeEmployeesProvider);
    return ContentDialog(
      title: Text('Assign ${widget.issue.issueCode}'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_message != null) ...[
            InfoBar(title: Text(_message!), severity: InfoBarSeverity.error),
            const SizedBox(height: 12),
          ],
          InfoLabel(
            label: 'Assign to',
            child: employees.when(
              loading: () => const ProgressRing(),
              error: (e, _) => const Text('Could not load employees.'),
              data: (list) => ComboBox<String>(
                value: _employee,
                placeholder: const Text('Choose'),
                items: [
                  for (final e in list)
                    ComboBoxItem<String>(
                      value: e.employeeId,
                      child: Text('${e.name} (${e.employeeId})'),
                    ),
                ],
                onChanged: _saving ? null : (v) => setState(() => _employee = v),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
