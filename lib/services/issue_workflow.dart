import '../models/app_user.dart';
import '../models/issue.dart';
import 'task_access.dart';

/// The part a person plays on one issue.
enum IssueActor { reporter, assignee, lead }

/// Who the person is on this issue. A person can be several at once.
class IssueAccess {
  const IssueAccess._();

  static Set<IssueActor> actorsFor(AppUser user, IssueItem issue) => {
        if (user.employee.employeeId == issue.reportedByEmployeeId)
          IssueActor.reporter,
        if (issue.assignedEmployeeId.isNotEmpty &&
            user.employee.employeeId == issue.assignedEmployeeId)
          IssueActor.assignee,
        if (TaskAccess.forUser(user).isLead) IssueActor.lead,
      };
}

/// One allowed status change.
class IssueMove {
  const IssueMove({
    required this.from,
    required this.to,
    required this.actor,
    required this.label,
    this.remarksLabel,
  });

  final IssueStatus from;
  final IssueStatus to;

  /// Who may make this change.
  final IssueActor actor;

  /// Button text.
  final String label;

  /// When not null, the person must type this reason or remark.
  final String? remarksLabel;

  bool get needsRemarks => remarksLabel != null;
}

/// The only place that defines which issue status changes are allowed.
///
/// Open > Assigned (by a lead, see IssueService.assign) > Investigating >
/// Waiting or Resolved > Closed. A resolved issue can be reopened.
/// Closed is final.
class IssueWorkflow {
  const IssueWorkflow._();

  static const _closeWithoutFix = 'Reason for closing';

  static const _moves = <IssueMove>[
    IssueMove(
      from: IssueStatus.open,
      to: IssueStatus.closed,
      actor: IssueActor.lead,
      label: 'Close without fixing',
      remarksLabel: _closeWithoutFix,
    ),
    IssueMove(
      from: IssueStatus.assigned,
      to: IssueStatus.investigating,
      actor: IssueActor.assignee,
      label: 'Start investigating',
    ),
    IssueMove(
      from: IssueStatus.assigned,
      to: IssueStatus.closed,
      actor: IssueActor.lead,
      label: 'Close without fixing',
      remarksLabel: _closeWithoutFix,
    ),
    IssueMove(
      from: IssueStatus.investigating,
      to: IssueStatus.waiting,
      actor: IssueActor.assignee,
      label: 'Set to waiting',
      remarksLabel: 'What are you waiting for',
    ),
    IssueMove(
      from: IssueStatus.investigating,
      to: IssueStatus.resolved,
      actor: IssueActor.assignee,
      label: 'Mark resolved',
      remarksLabel: 'Resolution remarks',
    ),
    IssueMove(
      from: IssueStatus.investigating,
      to: IssueStatus.closed,
      actor: IssueActor.lead,
      label: 'Close without fixing',
      remarksLabel: _closeWithoutFix,
    ),
    IssueMove(
      from: IssueStatus.waiting,
      to: IssueStatus.investigating,
      actor: IssueActor.assignee,
      label: 'Resume investigating',
    ),
    IssueMove(
      from: IssueStatus.waiting,
      to: IssueStatus.resolved,
      actor: IssueActor.assignee,
      label: 'Mark resolved',
      remarksLabel: 'Resolution remarks',
    ),
    IssueMove(
      from: IssueStatus.waiting,
      to: IssueStatus.closed,
      actor: IssueActor.lead,
      label: 'Close without fixing',
      remarksLabel: _closeWithoutFix,
    ),
    IssueMove(
      from: IssueStatus.resolved,
      to: IssueStatus.closed,
      actor: IssueActor.reporter,
      label: 'Confirm and close',
    ),
    IssueMove(
      from: IssueStatus.resolved,
      to: IssueStatus.closed,
      actor: IssueActor.lead,
      label: 'Confirm and close',
    ),
    IssueMove(
      from: IssueStatus.resolved,
      to: IssueStatus.investigating,
      actor: IssueActor.reporter,
      label: 'Reopen',
      remarksLabel: 'Reason for reopening',
    ),
    IssueMove(
      from: IssueStatus.resolved,
      to: IssueStatus.investigating,
      actor: IssueActor.lead,
      label: 'Reopen',
      remarksLabel: 'Reason for reopening',
    ),
  ];

  /// The changes [actors] may make from [from], one per target status.
  static List<IssueMove> movesFor(IssueStatus from, Set<IssueActor> actors) {
    final result = <IssueMove>[];
    for (final m in _moves) {
      if (m.from == from &&
          actors.contains(m.actor) &&
          !result.any((r) => r.to == m.to)) {
        result.add(m);
      }
    }
    return result;
  }

  /// The matching allowed change, or null when it is not allowed.
  static IssueMove? find(
    IssueStatus from,
    IssueStatus to,
    Set<IssueActor> actors,
  ) {
    for (final m in _moves) {
      if (m.from == from && m.to == to && actors.contains(m.actor)) return m;
    }
    return null;
  }
}
