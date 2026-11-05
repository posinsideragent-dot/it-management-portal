import '../models/task_enums.dart';
import 'task_access.dart';

/// One allowed status change.
class TaskMove {
  const TaskMove({
    required this.from,
    required this.to,
    required this.actor,
    required this.label,
    this.remarksLabel,
  });

  final TaskStatus from;
  final TaskStatus to;

  /// Who may make this change.
  final TaskActor actor;

  /// Button text.
  final String label;

  /// When not null, the person must type this reason or remark.
  final String? remarksLabel;

  bool get needsRemarks => remarksLabel != null;
}

/// The only place that defines which status changes are allowed.
///
/// New > Accepted > In Progress > Pending Review > Completed,
/// plus On Hold and Cancelled. Completed and Cancelled are final.
class TaskWorkflow {
  const TaskWorkflow._();

  static const _moves = <TaskMove>[
    TaskMove(
      from: TaskStatus.newTask,
      to: TaskStatus.accepted,
      actor: TaskActor.assignee,
      label: 'Accept',
    ),
    TaskMove(
      from: TaskStatus.newTask,
      to: TaskStatus.cancelled,
      actor: TaskActor.lead,
      label: 'Cancel task',
      remarksLabel: 'Reason for cancelling',
    ),
    TaskMove(
      from: TaskStatus.accepted,
      to: TaskStatus.inProgress,
      actor: TaskActor.assignee,
      label: 'Start work',
    ),
    TaskMove(
      from: TaskStatus.accepted,
      to: TaskStatus.onHold,
      actor: TaskActor.assignee,
      label: 'Put on hold',
      remarksLabel: 'Reason for holding',
    ),
    TaskMove(
      from: TaskStatus.accepted,
      to: TaskStatus.cancelled,
      actor: TaskActor.lead,
      label: 'Cancel task',
      remarksLabel: 'Reason for cancelling',
    ),
    TaskMove(
      from: TaskStatus.inProgress,
      to: TaskStatus.onHold,
      actor: TaskActor.assignee,
      label: 'Put on hold',
      remarksLabel: 'Reason for holding',
    ),
    TaskMove(
      from: TaskStatus.inProgress,
      to: TaskStatus.pendingReview,
      actor: TaskActor.assignee,
      label: 'Submit for review',
      remarksLabel: 'Completion remarks',
    ),
    TaskMove(
      from: TaskStatus.inProgress,
      to: TaskStatus.cancelled,
      actor: TaskActor.lead,
      label: 'Cancel task',
      remarksLabel: 'Reason for cancelling',
    ),
    TaskMove(
      from: TaskStatus.onHold,
      to: TaskStatus.inProgress,
      actor: TaskActor.assignee,
      label: 'Resume work',
    ),
    TaskMove(
      from: TaskStatus.onHold,
      to: TaskStatus.cancelled,
      actor: TaskActor.lead,
      label: 'Cancel task',
      remarksLabel: 'Reason for cancelling',
    ),
    TaskMove(
      from: TaskStatus.pendingReview,
      to: TaskStatus.completed,
      actor: TaskActor.lead,
      label: 'Approve',
    ),
    TaskMove(
      from: TaskStatus.pendingReview,
      to: TaskStatus.inProgress,
      actor: TaskActor.lead,
      label: 'Return for rework',
      remarksLabel: 'Reason for returning',
    ),
  ];

  /// The changes [actors] may make from [from]. Empty for final statuses.
  static List<TaskMove> movesFor(TaskStatus from, Set<TaskActor> actors) =>
      _moves
          .where((m) => m.from == from && actors.contains(m.actor))
          .toList();

  /// The matching allowed change, or null when it is not allowed.
  static TaskMove? find(
    TaskStatus from,
    TaskStatus to,
    Set<TaskActor> actors,
  ) {
    for (final m in _moves) {
      if (m.from == from && m.to == to && actors.contains(m.actor)) return m;
    }
    return null;
  }
}
