import '../core/configuration/app_config.dart';
import 'task_enums.dart';

/// The values a Team Lead types into the task form.
class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.taskType,
    required this.assignedEmployeeId,
    required this.priority,
    required this.estimatedHours,
    required this.expectedCompletion,
    required this.documentationRequired,
    this.projectCode = '',
    this.plannedStart,
  });

  final String title;
  final String description;
  final String taskType;
  final String assignedEmployeeId;
  final String priority;
  final String projectCode;

  /// Null means the box is empty or not a number.
  final double? estimatedHours;

  /// UTC. Null means not chosen yet.
  final DateTime? plannedStart;
  final DateTime? expectedCompletion;
  final bool documentationRequired;

  TaskDraft normalized() => TaskDraft(
        title: title.trim(),
        description: description.trim(),
        taskType: taskType,
        assignedEmployeeId: assignedEmployeeId.trim().toUpperCase(),
        priority: priority,
        projectCode: projectCode.trim().toUpperCase(),
        estimatedHours: estimatedHours,
        plannedStart: plannedStart,
        expectedCompletion: expectedCompletion,
        documentationRequired: documentationRequired,
      );

  /// Fields for a new task. Code, creator and time come from the service.
  Map<String, Object?> toCreateFields({
    required String taskCode,
    required String createdByEmployeeId,
  }) =>
      {
        SpFields.title: title,
        SpFields.taskCode: taskCode,
        SpFields.description: description,
        SpFields.taskType: taskType,
        SpFields.assignedEmployeeId: assignedEmployeeId,
        SpFields.createdByEmployeeId: createdByEmployeeId,
        SpFields.priority: priority,
        SpFields.status: TaskStatus.newTask.label,
        SpFields.estimatedHours: estimatedHours,
        SpFields.expectedCompletion: _iso(expectedCompletion!),
        SpFields.progress: 0,
        SpFields.documentationRequired: documentationRequired,
        SpFields.documentationStatus: documentationRequired
            ? DocumentationStatus.pending.label
            : DocumentationStatus.notRequired.label,
        if (projectCode.isNotEmpty) SpFields.projectCode: projectCode,
        if (plannedStart != null) SpFields.plannedStart: _iso(plannedStart!),
      };

  /// Fields for an edit. The code, creator and original estimate are handled
  /// by the service. Empty optional values are sent as null to clear them.
  Map<String, Object?> toUpdateFields({required bool includeEstimate}) => {
        SpFields.title: title,
        SpFields.description: description,
        SpFields.taskType: taskType,
        SpFields.assignedEmployeeId: assignedEmployeeId,
        SpFields.priority: priority,
        SpFields.expectedCompletion: _iso(expectedCompletion!),
        SpFields.documentationRequired: documentationRequired,
        SpFields.projectCode: projectCode.isEmpty ? null : projectCode,
        SpFields.plannedStart:
            plannedStart == null ? null : _iso(plannedStart!),
        if (includeEstimate) SpFields.estimatedHours: estimatedHours,
      };

  static String _iso(DateTime value) => value.toUtc().toIso8601String();
}
