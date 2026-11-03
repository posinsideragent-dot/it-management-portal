import 'task_item.dart';

/// One page of tasks. [nextLink] is null on the last page.
class TaskPage {
  const TaskPage({required this.items, this.nextLink});

  final List<TaskItem> items;
  final String? nextLink;
}
