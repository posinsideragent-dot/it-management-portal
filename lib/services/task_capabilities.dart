import '../models/app_user.dart';
import '../models/task_enums.dart';
import '../models/task_item.dart';
import 'task_access.dart';

/// What one person may do with one task in Tasks step 2: estimate revisions
/// and documentation. The service enforces these rules. The screen uses the
/// same object to show or hide buttons, so the two never disagree.
///
/// App-level checks are for usability. SharePoint permissions are the real
/// security.
class TaskCapabilities {
  const TaskCapabilities({
    required this.canRequestRevision,
    required this.canDecideRevision,
    required this.canSubmitDocumentation,
    required this.canReviewDocumentation,
    required this.canWaiveDocumentation,
  });

  factory TaskCapabilities.of(AppUser user, TaskItem task) {
    final actors = TaskAccess.actorsFor(user, task);
    final isAssignee = actors.contains(TaskActor.assignee);
    final isLead = actors.contains(TaskActor.lead);
    final open = !task.status.isFinal;
    final docs = task.documentationStatus;
    final docsNeedWork = task.documentationRequired &&
        (docs == DocumentationStatus.pending ||
            docs == DocumentationStatus.rejected);

    return TaskCapabilities(
      canRequestRevision: (isAssignee || isLead) &&
          _revisionStatuses.contains(task.status) &&
          !task.hasPendingRevision,
      canDecideRevision: isLead && open && task.hasPendingRevision,
      canSubmitDocumentation:
          isAssignee && docsNeedWork && _workStatuses.contains(task.status),
      canReviewDocumentation: isLead &&
          open &&
          task.documentationRequired &&
          docs == DocumentationStatus.submitted,
      canWaiveDocumentation: isLead && open && docsNeedWork,
    );
  }

  final bool canRequestRevision;
  final bool canDecideRevision;
  final bool canSubmitDocumentation;
  final bool canReviewDocumentation;
  final bool canWaiveDocumentation;

  bool get hasAny =>
      canRequestRevision ||
      canDecideRevision ||
      canSubmitDocumentation ||
      canReviewDocumentation ||
      canWaiveDocumentation;

  /// The original estimate is fixed once accepted. A revision can be asked
  /// for while the work is open, and not after it is sent for review.
  static const _revisionStatuses = {
    TaskStatus.accepted,
    TaskStatus.inProgress,
    TaskStatus.onHold,
  };

  static const _workStatuses = {
    TaskStatus.accepted,
    TaskStatus.inProgress,
    TaskStatus.onHold,
    TaskStatus.pendingReview,
  };
}
