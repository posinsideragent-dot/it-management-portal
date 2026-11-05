import '../core/configuration/app_config.dart';
import 'task_enums.dart';

/// IT_Issues Status choice values.
enum IssueStatus {
  open('Open'),
  assigned('Assigned'),
  investigating('Investigating'),
  waiting('Waiting'),
  resolved('Resolved'),
  closed('Closed');

  const IssueStatus(this.label);
  final String label;

  /// Closed issues cannot change any more.
  bool get isFinal => this == IssueStatus.closed;

  static IssueStatus? tryParse(String value) {
    for (final s in IssueStatus.values) {
      if (s.label == value) return s;
    }
    return null;
  }
}

/// IT_Issues IssueType choice values.
const issueTypes = <String>[
  'Bug',
  'Support',
  'Infrastructure',
  'Hardware',
  'Software',
  'Security',
  'Blocker',
];

/// One row of the IT_Issues list.
class IssueItem {
  const IssueItem({
    required this.itemId,
    required this.etag,
    required this.issueCode,
    required this.title,
    required this.description,
    required this.issueType,
    required this.priority,
    required this.status,
    required this.reportedByEmployeeId,
    required this.reportedAtUtc,
    this.assignedEmployeeId = '',
    this.relatedTaskCode = '',
    this.projectCode = '',
    this.resolutionRemarks = '',
    this.resolvedAtUtc,
  });

  final String itemId;

  /// Sent as If-Match on updates.
  final String etag;

  /// Business id such as ISS-2026-00001. Unique. Never changes.
  final String issueCode;
  final String title;
  final String description;
  final String issueType;
  final TaskPriority priority;
  final IssueStatus status;
  final String reportedByEmployeeId;

  /// Empty until a Team Lead assigns the issue.
  final String assignedEmployeeId;
  final String relatedTaskCode;
  final String projectCode;

  /// The latest status note: "Waiting: ...", "Reopened: ...", "Closed: ...",
  /// or the resolution text itself once resolved.
  final String resolutionRemarks;

  /// UTC.
  final DateTime reportedAtUtc;
  final DateTime? resolvedAtUtc;

  /// [item] is a Graph list item requested with $expand=fields.
  factory IssueItem.fromGraphItem(Map<String, dynamic> item) {
    final f = (item['fields'] as Map<String, dynamic>?) ?? const {};
    String text(String key) => (f[key] ?? '').toString();
    return IssueItem(
      itemId: item['id'].toString(),
      etag: (item['eTag'] ?? item['@odata.etag'] ?? '').toString(),
      issueCode: text(SpFields.issueCode),
      title: text(SpFields.title),
      description: text(SpFields.description),
      issueType: text(SpFields.issueType),
      priority:
          TaskPriority.tryParse(text(SpFields.priority)) ?? TaskPriority.normal,
      status: IssueStatus.tryParse(text(SpFields.status)) ?? IssueStatus.open,
      reportedByEmployeeId: text(SpFields.reportedByEmployeeId),
      assignedEmployeeId: text(SpFields.assignedEmployeeId),
      relatedTaskCode: text(SpFields.relatedTaskCode),
      projectCode: text(SpFields.projectCode),
      resolutionRemarks: text(SpFields.resolutionRemarks),
      reportedAtUtc:
          _utc(f[SpFields.reportedAtUtc]) ?? DateTime.utc(1970),
      resolvedAtUtc: _utc(f[SpFields.resolvedAtUtc]),
    );
  }
}

/// The values a person types into the issue form.
class IssueDraft {
  const IssueDraft({
    required this.title,
    required this.description,
    required this.issueType,
    required this.priority,
    this.relatedTaskCode = '',
    this.projectCode = '',
  });

  final String title;
  final String description;
  final String issueType;
  final String priority;
  final String relatedTaskCode;
  final String projectCode;

  IssueDraft normalized() => IssueDraft(
        title: title.trim(),
        description: description.trim(),
        issueType: issueType,
        priority: priority,
        relatedTaskCode: relatedTaskCode.trim().toUpperCase(),
        projectCode: projectCode.trim().toUpperCase(),
      );

  /// Fields for a new issue. Code, reporter and time come from the service.
  Map<String, Object?> toCreateFields({
    required String issueCode,
    required String reportedByEmployeeId,
    required DateTime reportedAtUtc,
  }) =>
      {
        SpFields.title: title,
        SpFields.issueCode: issueCode,
        SpFields.description: description,
        SpFields.issueType: issueType,
        SpFields.priority: priority,
        SpFields.status: IssueStatus.open.label,
        SpFields.reportedByEmployeeId: reportedByEmployeeId,
        SpFields.reportedAtUtc: reportedAtUtc.toUtc().toIso8601String(),
        if (relatedTaskCode.isNotEmpty) SpFields.relatedTaskCode: relatedTaskCode,
        if (projectCode.isNotEmpty) SpFields.projectCode: projectCode,
      };

  /// Fields for an edit. Empty optional values are sent as null to clear them.
  Map<String, Object?> toUpdateFields() => {
        SpFields.title: title,
        SpFields.description: description,
        SpFields.issueType: issueType,
        SpFields.priority: priority,
        SpFields.relatedTaskCode: relatedTaskCode.isEmpty ? null : relatedTaskCode,
        SpFields.projectCode: projectCode.isEmpty ? null : projectCode,
      };
}

DateTime? _utc(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toUtc();
