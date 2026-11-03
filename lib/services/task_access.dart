import '../models/app_role.dart';
import '../models/app_user.dart';
import '../models/task_item.dart';

/// The part a person plays on one task.
enum TaskActor { assignee, lead }

/// What the app lets each person do with tasks.
///
/// This is for usability. SharePoint permissions are the real security.
/// Team Lead, Management and Admin can create, edit, cancel and review tasks.
/// Everyone can read tasks. The assignee works on their own tasks.
class TaskAccess {
  const TaskAccess(this.role);

  factory TaskAccess.forUser(AppUser user) =>
      TaskAccess(AppRole.parse(user.role));

  final AppRole role;

  bool get isLead =>
      role == AppRole.teamLead ||
      role == AppRole.management ||
      role == AppRole.admin;

  bool get canCreate => isLead;

  /// The roles [user] plays on [task]. A person can be both.
  static Set<TaskActor> actorsFor(AppUser user, TaskItem task) => {
        if (user.employee.employeeId == task.assignedEmployeeId)
          TaskActor.assignee,
        if (TaskAccess.forUser(user).isLead) TaskActor.lead,
      };
}
