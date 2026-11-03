import '../core/configuration/app_config.dart';
import '../core/utilities/malaysia_time.dart';
import '../data/api/graph_client.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/task_repository.dart';
import '../models/app_user.dart';
import '../models/task_draft.dart';
import '../models/task_enums.dart';
import '../models/task_item.dart';
import '../models/task_page.dart';
import 'task_access.dart';
import 'task_codes.dart';
import 'task_validator.dart';
import 'task_workflow.dart';

/// A task business rule was broken. [message] is safe to show to the user.
class TaskRuleException implements Exception {
  TaskRuleException(
    this.message, {
    this.fieldErrors = const <TaskFormField, String>{},
  });

  final String message;
  final Map<TaskFormField, String> fieldErrors;

  @override
  String toString() => message;
}

/// Business rules for the Tasks module (step 1: create, edit, status flow,
/// progress). Estimate revisions and documentation review come in step 2.
///
/// Role checks are app-level (usability). SharePoint permissions are the real
/// boundary. SharePoint version history is the audit trail.
class TaskService {
  TaskService(
    this._tasks,
    this._employees, {
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final TaskDirectory _tasks;
  final EmployeeDirectory _employees;
  final DateTime Function() _now;

  static const _maxCreateAttempts = 3;

  Future<TaskPage> listPage({
    String? status,
    String? assignedEmployeeId,
    String? nextLink,
  }) =>
      _tasks.listPage(
        status: status,
        assignedEmployeeId: assignedEmployeeId,
        nextLink: nextLink,
      );

  Future<TaskItem> create(AppUser actor, TaskDraft input) async {
    _requireLead(actor);
    final draft = input.normalized();
    _validate(draft, nowUtc: _now().toUtc());
    await _requireActiveAssignee(draft.assignedEmployeeId);

    final year = malaysiaYear(_now());
    for (var attempt = 1; attempt <= _maxCreateAttempts; attempt++) {
      final code = TaskCodes.next(await _tasks.highestTaskCode(), year);
      if (code == null) {
        throw TaskRuleException(
          'An existing TaskCode has an unexpected format or year. '
          "Ask IT to check the list and this PC's clock.",
        );
      }
      try {
        return await _tasks.create(
          draft.toCreateFields(
            taskCode: code,
            createdByEmployeeId: actor.employee.employeeId,
          ),
        );
      } on GraphException catch (e) {
        if (!e.isDuplicateValue) rethrow;
        // A duplicate means nothing was created, so another try is safe.
        if (attempt == _maxCreateAttempts) {
          throw TaskRuleException('Could not get a free TaskCode. Try again.');
        }
      }
    }
    throw StateError('unreachable');
  }

  Future<TaskItem> update(
    AppUser actor,
    TaskItem current,
    TaskDraft input,
  ) async {
    _requireLead(actor);
    if (current.status.isFinal) {
      throw TaskRuleException(
        '${current.status.label} tasks cannot be edited.',
      );
    }
    final draft = input.normalized();
    _validate(draft);

    // The original estimate is fixed once the task is accepted.
    final estimateOpen = current.status == TaskStatus.newTask;
    if (!estimateOpen && draft.estimatedHours != current.estimatedHours) {
      throw TaskRuleException(
        'The original estimate cannot change after the task is accepted.',
        fieldErrors: {
          TaskFormField.estimate: 'Locked. Use a revised estimate instead.',
        },
      );
    }
    if (draft.assignedEmployeeId != current.assignedEmployeeId) {
      await _requireActiveAssignee(draft.assignedEmployeeId);
    }
    return _save(
      current,
      draft.toUpdateFields(includeEstimate: estimateOpen),
    );
  }

  /// Moves the task to [to]. [remarks] is required for some moves
  /// (see [TaskWorkflow]).
  Future<TaskItem> changeStatus(
    AppUser actor,
    TaskItem current,
    TaskStatus to, {
    String remarks = '',
  }) async {
    final move = TaskWorkflow.find(
      current.status,
      to,
      TaskAccess.actorsFor(actor, current),
    );
    if (move == null) {
      throw TaskRuleException(
        'You cannot change this task from ${current.status.label} '
        'to ${to.label}.',
      );
    }
    final text = remarks.trim();
    if (move.needsRemarks && text.isEmpty) {
      throw TaskRuleException('Enter: ${move.remarksLabel}.');
    }

    final now = _now().toUtc().toIso8601String();
    final fields = <String, Object?>{
      SpFields.status: to.label,
      SpFields.lastProgressUpdateUtc: now,
    };

    switch (to) {
      case TaskStatus.inProgress:
        // First start only. Later restarts keep the first date.
        if (current.actualStart == null) fields[SpFields.actualStart] = now;
        if (current.status == TaskStatus.pendingReview) {
          fields[SpFields.blockerRemarks] = 'Returned: $text';
        }
      case TaskStatus.onHold:
        fields[SpFields.blockerRemarks] = 'On hold: $text';
      case TaskStatus.cancelled:
        fields[SpFields.blockerRemarks] = 'Cancelled: $text';
      case TaskStatus.pendingReview:
        fields[SpFields.completionRemarks] = text;
      case TaskStatus.completed:
        if (current.completionRemarks.trim().isEmpty) {
          throw TaskRuleException('Completion remarks are missing.');
        }
        if (!current.documentationStatus.isSatisfied) {
          throw TaskRuleException(
            'Required documentation must be submitted or waived '
            'before approval.',
          );
        }
        fields[SpFields.actualCompletion] = now;
        fields[SpFields.reviewedByEmployeeId] = actor.employee.employeeId;
        fields[SpFields.progress] = 100;
      case TaskStatus.newTask:
      case TaskStatus.accepted:
        break;
    }
    return _save(current, fields);
  }

  /// The assignee sets progress (0 to 100) while the task is In Progress.
  Future<TaskItem> updateProgress(
    AppUser actor,
    TaskItem current,
    int progress,
  ) async {
    if (!TaskAccess.actorsFor(actor, current).contains(TaskActor.assignee)) {
      throw TaskRuleException('Only the assigned person can update progress.');
    }
    if (current.status != TaskStatus.inProgress) {
      throw TaskRuleException('Progress can be updated while In Progress.');
    }
    if (progress < 0 || progress > 100) {
      throw TaskRuleException('Progress must be between 0 and 100.');
    }
    return _save(current, {
      SpFields.progress: progress,
      SpFields.lastProgressUpdateUtc: _now().toUtc().toIso8601String(),
    });
  }

  // --- helpers ---

  void _requireLead(AppUser actor) {
    if (!TaskAccess.forUser(actor).canCreate) {
      throw TaskRuleException(
        'Only a Team Lead, Management or Admin can create or edit tasks.',
      );
    }
  }

  void _validate(TaskDraft draft, {DateTime? nowUtc}) {
    final errors = TaskValidator.validate(draft, nowUtc: nowUtc);
    if (errors.isNotEmpty) {
      throw TaskRuleException(
        'Please fix the highlighted fields.',
        fieldErrors: errors,
      );
    }
  }

  Future<void> _requireActiveAssignee(String employeeId) async {
    final employee = await _employees.findByEmployeeId(employeeId);
    if (employee == null || !employee.isActive) {
      throw TaskRuleException(
        'The assigned employee was not found or is inactive.',
        fieldErrors: {
          TaskFormField.assignee: 'Choose an active employee.',
        },
      );
    }
  }

  Future<TaskItem> _save(TaskItem current, Map<String, Object?> fields) async {
    try {
      return await _tasks.update(current: current, fields: fields);
    } on GraphException catch (e) {
      if (e.isPreconditionFailed) {
        throw TaskRuleException(
          'Someone else changed this task. Reload the list and try again.',
        );
      }
      rethrow;
    }
  }
}
