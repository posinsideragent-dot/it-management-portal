import '../core/utilities/malaysia_time.dart';
import '../models/task_draft.dart';
import '../models/task_enums.dart';

/// Task form fields that can have an error.
enum TaskFormField {
  title,
  description,
  taskType,
  assignee,
  priority,
  estimate,
  plannedStart,
  expectedCompletion,
  projectCode,
  companyName,
  attn,
  contactNumber,
}

/// Rules for the task form. The UI uses it for quick feedback and the service
/// uses it again before saving.
class TaskValidator {
  const TaskValidator._();

  static const maxEstimateHours = 1000.0;
  static const maxCustomerText = 255;
  static const maxContactNumber = 50;
  static final _digit = RegExp(r'\d');
  static final _employeeId = RegExp(r'^EMP-\d{4,}$');

  /// An empty map means the draft is valid. Pass [nowUtc] on create so a
  /// completion date in the past is refused.
  static Map<TaskFormField, String> validate(
    TaskDraft input, {
    DateTime? nowUtc,
  }) {
    final d = input.normalized();
    final errors = <TaskFormField, String>{};

    if (d.title.isEmpty) {
      errors[TaskFormField.title] = 'Enter a title.';
    } else if (d.title.length > 255) {
      errors[TaskFormField.title] = 'The title is too long.';
    }

    if (d.description.isEmpty) {
      errors[TaskFormField.description] = 'Enter a description.';
    }

    if (!taskTypes.contains(d.taskType)) {
      errors[TaskFormField.taskType] = 'Choose a task type.';
    }

    if (!_employeeId.hasMatch(d.assignedEmployeeId)) {
      errors[TaskFormField.assignee] = 'Choose who the task is assigned to.';
    }

    if (!TaskPriority.labels.contains(d.priority)) {
      errors[TaskFormField.priority] = 'Choose a priority.';
    }

    final estimate = d.estimatedHours;
    if (estimate == null) {
      errors[TaskFormField.estimate] = 'Enter the estimated hours.';
    } else if (estimate <= 0) {
      errors[TaskFormField.estimate] = 'The estimate must be more than 0.';
    } else if (estimate > maxEstimateHours) {
      errors[TaskFormField.estimate] =
          'The estimate cannot be more than ${maxEstimateHours.toInt()} hours.';
    }

    final due = d.expectedCompletion;
    if (due == null) {
      errors[TaskFormField.expectedCompletion] =
          'Choose the expected completion date.';
    } else if (nowUtc != null && isMalaysiaDateBefore(due, nowUtc)) {
      errors[TaskFormField.expectedCompletion] =
          'The expected completion date cannot be in the past.';
    }

    final start = d.plannedStart;
    if (start != null && due != null && isMalaysiaDateBefore(due, start)) {
      errors[TaskFormField.plannedStart] =
          'The planned start date cannot be after the expected completion date.';
    }

    if (d.companyName.length > maxCustomerText) {
      errors[TaskFormField.companyName] = 'The company name is too long.';
    }
    if (d.attn.length > maxCustomerText) {
      errors[TaskFormField.attn] = 'The Attn name is too long.';
    }
    if (d.contactNumber.isNotEmpty &&
        (d.contactNumber.length > maxContactNumber ||
            !_digit.hasMatch(d.contactNumber))) {
      errors[TaskFormField.contactNumber] =
          'Enter a valid contact number (up to $maxContactNumber characters).';
    }

    if (d.projectCode.length > 50) {
      errors[TaskFormField.projectCode] = 'The project code is too long.';
    }

    return errors;
  }
}
