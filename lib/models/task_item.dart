import '../core/configuration/app_config.dart';
import 'task_enums.dart';

/// One row of the IT_Tasks list.
class TaskItem {
  const TaskItem({
    required this.itemId,
    required this.etag,
    required this.taskCode,
    required this.title,
    required this.description,
    required this.taskType,
    required this.assignedEmployeeId,
    required this.createdByEmployeeId,
    required this.priority,
    required this.status,
    required this.estimatedHours,
    required this.expectedCompletion,
    required this.progress,
    required this.documentationRequired,
    required this.documentationStatus,
    this.projectCode = '',
    this.revisedEstimatedHours,
    this.plannedStart,
    this.actualStart,
    this.actualCompletion,
    this.blockerRemarks = '',
    this.completionRemarks = '',
    this.reviewedByEmployeeId = '',
    this.lastProgressUpdateUtc,
    this.estimateRevisionReason = '',
    this.estimateApprovedBy = '',
    this.estimateApprovedAtUtc,
  });

  /// SharePoint list item id.
  final String itemId;

  /// Sent as If-Match on updates.
  final String etag;

  /// Business id such as TASK-2026-00001. Unique. Never changes.
  final String taskCode;
  final String title;
  final String description;
  final String taskType;
  final String assignedEmployeeId;
  final String createdByEmployeeId;
  final String projectCode;
  final TaskPriority priority;
  final TaskStatus status;

  /// The original estimate. A revision never overwrites it.
  final double estimatedHours;
  final double? revisedEstimatedHours;

  /// All dates are UTC. Show them in Malaysia time.
  final DateTime? plannedStart;
  final DateTime expectedCompletion;
  final DateTime? actualStart;
  final DateTime? actualCompletion;

  /// 0 to 100.
  final int progress;
  final String blockerRemarks;
  final String completionRemarks;
  final bool documentationRequired;
  final DocumentationStatus documentationStatus;
  final String reviewedByEmployeeId;
  final DateTime? lastProgressUpdateUtc;
  final String estimateRevisionReason;
  final String estimateApprovedBy;
  final DateTime? estimateApprovedAtUtc;

  /// True when a revised estimate is waiting for Team Lead approval.
  bool get hasPendingRevision =>
      revisedEstimatedHours != null && estimateApprovedBy.isEmpty;

  /// [item] is a Graph list item requested with $expand=fields.
  factory TaskItem.fromGraphItem(Map<String, dynamic> item) {
    final f = (item['fields'] as Map<String, dynamic>?) ?? const {};
    String text(String key) => (f[key] ?? '').toString();
    return TaskItem(
      itemId: item['id'].toString(),
      etag: (item['eTag'] ?? item['@odata.etag'] ?? '').toString(),
      taskCode: text(SpFields.taskCode),
      title: text(SpFields.title),
      description: text(SpFields.description),
      taskType: text(SpFields.taskType),
      assignedEmployeeId: text(SpFields.assignedEmployeeId),
      createdByEmployeeId: text(SpFields.createdByEmployeeId),
      projectCode: text(SpFields.projectCode),
      // An unknown choice falls back to the safest reading.
      priority:
          TaskPriority.tryParse(text(SpFields.priority)) ?? TaskPriority.normal,
      status: TaskStatus.tryParse(text(SpFields.status)) ?? TaskStatus.newTask,
      estimatedHours: _number(f[SpFields.estimatedHours]) ?? 0,
      revisedEstimatedHours: _number(f[SpFields.revisedEstimatedHours]),
      plannedStart: _utc(f[SpFields.plannedStart]),
      expectedCompletion:
          _utc(f[SpFields.expectedCompletion]) ?? DateTime.utc(1970),
      actualStart: _utc(f[SpFields.actualStart]),
      actualCompletion: _utc(f[SpFields.actualCompletion]),
      progress: (_number(f[SpFields.progress]) ?? 0).round().clamp(0, 100),
      blockerRemarks: text(SpFields.blockerRemarks),
      completionRemarks: text(SpFields.completionRemarks),
      documentationRequired: f[SpFields.documentationRequired] == true,
      documentationStatus:
          DocumentationStatus.tryParse(text(SpFields.documentationStatus)) ??
              DocumentationStatus.pending,
      reviewedByEmployeeId: text(SpFields.reviewedByEmployeeId),
      lastProgressUpdateUtc: _utc(f[SpFields.lastProgressUpdateUtc]),
      estimateRevisionReason: text(SpFields.estimateRevisionReason),
      estimateApprovedBy: text(SpFields.estimateApprovedBy),
      estimateApprovedAtUtc: _utc(f[SpFields.estimateApprovedAtUtc]),
    );
  }
}

double? _number(Object? value) => value is num ? value.toDouble() : null;

DateTime? _utc(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toUtc();
