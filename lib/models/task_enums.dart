// Choice values of IT_Tasks. The labels are the exact SharePoint values.

enum TaskStatus {
  newTask('New'),
  accepted('Accepted'),
  inProgress('In Progress'),
  onHold('On Hold'),
  pendingReview('Pending Review'),
  completed('Completed'),
  cancelled('Cancelled');

  const TaskStatus(this.label);
  final String label;

  /// Completed and Cancelled tasks cannot change any more.
  bool get isFinal =>
      this == TaskStatus.completed || this == TaskStatus.cancelled;

  /// Returns null for an unknown value, so the caller can decide.
  static TaskStatus? tryParse(String value) {
    for (final s in TaskStatus.values) {
      if (s.label == value) return s;
    }
    return null;
  }
}

enum TaskPriority {
  low('Low'),
  normal('Normal'),
  high('High'),
  critical('Critical');

  const TaskPriority(this.label);
  final String label;

  static TaskPriority? tryParse(String value) {
    for (final p in TaskPriority.values) {
      if (p.label == value) return p;
    }
    return null;
  }

  static List<String> get labels => values.map((p) => p.label).toList();
}

const taskTypes = <String>[
  'Development',
  'Bug Fix',
  'Support',
  'Installation',
  'Maintenance',
  'Research',
  'Internal IT',
];

enum DocumentationStatus {
  notRequired('Not Required'),
  pending('Pending'),
  submitted('Submitted'),
  reviewed('Reviewed'),
  rejected('Rejected');

  const DocumentationStatus(this.label);
  final String label;

  /// Documentation is done: submitted, reviewed, or formally waived.
  bool get isSatisfied =>
      this == DocumentationStatus.notRequired ||
      this == DocumentationStatus.submitted ||
      this == DocumentationStatus.reviewed;

  static DocumentationStatus? tryParse(String value) {
    for (final d in DocumentationStatus.values) {
      if (d.label == value) return d;
    }
    return null;
  }
}
