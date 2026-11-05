import '../core/configuration/app_config.dart';
import '../core/errors/rule_violation.dart';
import '../core/utilities/malaysia_time.dart';
import '../data/api/graph_client.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/issue_repository.dart';
import '../models/app_user.dart';
import '../models/issue.dart';
import '../models/task_enums.dart';
import 'issue_codes.dart';
import 'issue_workflow.dart';
import 'task_access.dart';

/// Issue form fields that can have an error.
enum IssueFormField { title, description, issueType, priority, relatedTask, project }

/// An issue rule was broken. [message] is safe to show to the user.
class IssueRuleException implements RuleViolation {
  IssueRuleException(
    this.message, {
    this.fieldErrors = const <IssueFormField, String>{},
  });

  @override
  final String message;
  final Map<IssueFormField, String> fieldErrors;

  @override
  String toString() => message;
}

/// Business rules for the Issues module.
///
/// Anyone can report an issue. A Team Lead, Management or Admin assigns it.
/// The assignee investigates and resolves it. The reporter or a lead confirms
/// and closes it. Role checks are app-level (usability). SharePoint
/// permissions are the real boundary. SharePoint version history is the
/// audit trail.
class IssueService {
  IssueService(
    this._issues,
    this._employees, {
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final IssueDirectory _issues;
  final EmployeeDirectory _employees;
  final DateTime Function() _now;

  static const _maxCreateAttempts = 3;
  static final _taskCode = RegExp(r'^TASK-\d{4}-\d{5,}$');

  Future<IssuePage> listPage({
    String? status,
    String? assignedEmployeeId,
    String? nextLink,
  }) =>
      _issues.listPage(
        status: status,
        assignedEmployeeId: assignedEmployeeId,
        nextLink: nextLink,
      );

  /// Reports a new issue. Anyone signed in can do this.
  Future<IssueItem> create(AppUser actor, IssueDraft input) async {
    final draft = input.normalized();
    _validate(draft);
    final now = _now().toUtc();
    final year = malaysiaYear(now);

    for (var attempt = 1; attempt <= _maxCreateAttempts; attempt++) {
      final code = IssueCodes.next(await _issues.highestIssueCode(), year);
      if (code == null) {
        throw IssueRuleException(
          'An existing IssueCode has an unexpected format or year. '
          "Ask IT to check the list and this PC's clock.",
        );
      }
      try {
        return await _issues.create(
          draft.toCreateFields(
            issueCode: code,
            reportedByEmployeeId: actor.employee.employeeId,
            reportedAtUtc: now,
          ),
        );
      } on GraphException catch (e) {
        if (!e.isDuplicateValue) rethrow;
        // A duplicate means nothing was created, so another try is safe.
        if (attempt == _maxCreateAttempts) {
          throw IssueRuleException('Could not get a free IssueCode. Try again.');
        }
      }
    }
    throw StateError('unreachable');
  }

  /// The reporter can edit while the issue is Open. A lead can edit until it
  /// is Closed.
  Future<IssueItem> update(
    AppUser actor,
    IssueItem current,
    IssueDraft input,
  ) async {
    final actors = IssueAccess.actorsFor(actor, current);
    final isLead = actors.contains(IssueActor.lead);
    final reporterMayEdit =
        actors.contains(IssueActor.reporter) && current.status == IssueStatus.open;
    if (current.status.isFinal) {
      throw IssueRuleException('Closed issues cannot be edited.');
    }
    if (!isLead && !reporterMayEdit) {
      throw IssueRuleException(
        'The reporter can edit an Open issue. A Team Lead can edit any issue '
        'that is not Closed.',
      );
    }
    final draft = input.normalized();
    _validate(draft);
    return _save(current, draft.toUpdateFields());
  }

  /// A lead gives the issue to an active employee. An Open issue becomes
  /// Assigned. An issue already being worked on keeps its status.
  Future<IssueItem> assign(
    AppUser actor,
    IssueItem current,
    String employeeId,
  ) async {
    if (!TaskAccess.forUser(actor).isLead) {
      throw IssueRuleException(
        'Only a Team Lead, Management or Admin can assign issues.',
      );
    }
    const assignable = {
      IssueStatus.open,
      IssueStatus.assigned,
      IssueStatus.investigating,
      IssueStatus.waiting,
    };
    if (!assignable.contains(current.status)) {
      throw IssueRuleException(
        'A ${current.status.label} issue cannot be assigned. Reopen it first.',
      );
    }
    final id = employeeId.trim().toUpperCase();
    final employee = await _employees.findByEmployeeId(id);
    if (employee == null || !employee.isActive) {
      throw IssueRuleException(
        'The assigned employee was not found or is inactive.',
      );
    }
    return _save(current, {
      SpFields.assignedEmployeeId: id,
      if (current.status == IssueStatus.open)
        SpFields.status: IssueStatus.assigned.label,
    });
  }

  /// Moves the issue to [to]. [remarks] is required for some moves
  /// (see [IssueWorkflow]).
  Future<IssueItem> changeStatus(
    AppUser actor,
    IssueItem current,
    IssueStatus to, {
    String remarks = '',
  }) async {
    final move = IssueWorkflow.find(
      current.status,
      to,
      IssueAccess.actorsFor(actor, current),
    );
    if (move == null) {
      throw IssueRuleException(
        'You cannot change this issue from ${current.status.label} '
        'to ${to.label}.',
      );
    }
    final text = remarks.trim();
    if (move.needsRemarks && text.isEmpty) {
      throw IssueRuleException('Enter: ${move.remarksLabel}.');
    }

    final fields = <String, Object?>{SpFields.status: to.label};
    switch (to) {
      case IssueStatus.waiting:
        fields[SpFields.resolutionRemarks] = 'Waiting: $text';
      case IssueStatus.resolved:
        fields[SpFields.resolutionRemarks] = text;
        fields[SpFields.resolvedAtUtc] = _now().toUtc().toIso8601String();
      case IssueStatus.investigating:
        if (current.status == IssueStatus.resolved) {
          fields[SpFields.resolutionRemarks] = 'Reopened: $text';
          fields[SpFields.resolvedAtUtc] = null;
        }
      case IssueStatus.closed:
        // Confirming a resolved issue keeps the resolution text.
        if (current.status != IssueStatus.resolved) {
          fields[SpFields.resolutionRemarks] = 'Closed: $text';
        }
      case IssueStatus.open:
      case IssueStatus.assigned:
        break;
    }
    return _save(current, fields);
  }

  // --- helpers ---

  void _validate(IssueDraft draft) {
    final errors = <IssueFormField, String>{};
    if (draft.title.isEmpty) {
      errors[IssueFormField.title] = 'Enter a title.';
    } else if (draft.title.length > 255) {
      errors[IssueFormField.title] = 'The title is too long.';
    }
    if (draft.description.isEmpty) {
      errors[IssueFormField.description] = 'Describe the issue.';
    }
    if (!issueTypes.contains(draft.issueType)) {
      errors[IssueFormField.issueType] = 'Choose an issue type.';
    }
    if (!TaskPriority.labels.contains(draft.priority)) {
      errors[IssueFormField.priority] = 'Choose a priority.';
    }
    if (draft.relatedTaskCode.isNotEmpty &&
        !_taskCode.hasMatch(draft.relatedTaskCode)) {
      errors[IssueFormField.relatedTask] = 'Use a code like TASK-2026-00001.';
    }
    if (draft.projectCode.length > 50) {
      errors[IssueFormField.project] = 'The project code is too long.';
    }
    if (errors.isNotEmpty) {
      throw IssueRuleException(
        'Please fix the highlighted fields.',
        fieldErrors: errors,
      );
    }
  }

  Future<IssueItem> _save(IssueItem current, Map<String, Object?> fields) async {
    try {
      return await _issues.update(current: current, fields: fields);
    } on GraphException catch (e) {
      if (e.isPreconditionFailed) {
        throw IssueRuleException(
          'Someone else changed this issue. Reload the list and try again.',
        );
      }
      rethrow;
    }
  }
}
