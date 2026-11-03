import '../core/configuration/app_config.dart';
import '../data/api/graph_client.dart';
import '../data/repositories/employee_repository.dart';
import '../models/app_role.dart';
import '../models/app_user.dart';
import '../models/employee.dart';
import '../models/employee_draft.dart';
import '../models/employee_page.dart';
import 'employee_access.dart';
import 'employee_ids.dart';
import 'employee_validator.dart';

/// A business rule was broken. [message] is safe to show to the user.
class EmployeeRuleException implements Exception {
  EmployeeRuleException(
    this.message, {
    this.fieldErrors = const <EmployeeFormField, String>{},
  });

  final String message;
  final Map<EmployeeFormField, String> fieldErrors;

  @override
  String toString() => message;
}

/// Business rules for the Employees module.
///
/// The role checks here are app-level (usability). SharePoint permissions
/// remain the real security boundary.
///
/// Audit trail: SharePoint version history on IT_Employees records who changed
/// each row and when. See docs/SharePointSchema.md.
class EmployeeService {
  EmployeeService(this._directory, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final EmployeeDirectory _directory;
  final DateTime Function() _now;

  static const _maxCreateAttempts = 3;

  Future<EmployeePage> listPage({bool? isActive, String? nextLink}) =>
      _directory.listPage(isActive: isActive, nextLink: nextLink);

  Future<Employee> create(AppUser actor, EmployeeDraft input) async {
    _requireManager(actor);
    final draft = input.normalized();
    _validate(draft, isCreate: true);
    await _checkManagerExists(draft.managerEmployeeId);

    if (await _directory.findByEntraObjectId(draft.entraObjectId) != null) {
      throw _alreadyRegistered();
    }

    for (var attempt = 1; attempt <= _maxCreateAttempts; attempt++) {
      final employeeId = EmployeeIds.next(await _directory.highestEmployeeId());
      if (employeeId == null) {
        throw EmployeeRuleException(
          'An existing EmployeeID has an unexpected format. Ask IT to check the list.',
        );
      }
      try {
        return await _directory.create(
          draft.toCreateFields(
            employeeId: employeeId,
            createdAtUtc: _now().toUtc(),
          ),
        );
      } on GraphException catch (e) {
        if (!e.isDuplicateValue) rethrow;
        // A duplicate means nothing was created, so another try is safe.
        // Either someone registered this account, or took this EmployeeID.
        if (await _directory.findByEntraObjectId(draft.entraObjectId) != null) {
          throw _alreadyRegistered();
        }
        if (attempt == _maxCreateAttempts) {
          throw EmployeeRuleException(
            'Could not get a free EmployeeID. Try again.',
          );
        }
      }
    }
    throw StateError('unreachable');
  }

  Future<Employee> update(
    AppUser actor,
    Employee current,
    EmployeeDraft input,
  ) async {
    _requireManager(actor);
    final draft = input.normalized();
    _validate(draft, isCreate: false);

    final isSelf = actor.employee.employeeId == current.employeeId;
    if (isSelf && draft.appRole != current.appRole) {
      throw EmployeeRuleException('You cannot change your own role.');
    }
    if (draft.managerEmployeeId == current.employeeId) {
      throw EmployeeRuleException(
        'An employee cannot be their own manager.',
        fieldErrors: {
          EmployeeFormField.managerEmployeeId: 'Choose someone else.',
        },
      );
    }
    await _checkManagerExists(draft.managerEmployeeId);
    return _save(current, draft.toUpdateFields());
  }

  /// Deactivates or reactivates. Rows are never deleted.
  Future<Employee> setActive(
    AppUser actor,
    Employee current, {
    required bool active,
  }) async {
    _requireManager(actor);
    if (current.isActive == active) return current;
    if (!active && actor.employee.employeeId == current.employeeId) {
      throw EmployeeRuleException('You cannot deactivate your own account.');
    }
    return _save(current, {SpFields.isActive: active});
  }

  // --- helpers ---

  void _requireManager(AppUser actor) {
    if (!EmployeeAccess(AppRole.parse(actor.role)).canManage) {
      throw EmployeeRuleException(
        'Only Management or Admin can change employees.',
      );
    }
  }

  void _validate(EmployeeDraft draft, {required bool isCreate}) {
    final errors = EmployeeValidator.validate(draft, isCreate: isCreate);
    if (errors.isNotEmpty) {
      throw EmployeeRuleException(
        'Please fix the highlighted fields.',
        fieldErrors: errors,
      );
    }
  }

  Future<void> _checkManagerExists(String managerEmployeeId) async {
    if (managerEmployeeId.isEmpty) return;
    if (await _directory.findByEmployeeId(managerEmployeeId) == null) {
      throw EmployeeRuleException(
        'The manager was not found.',
        fieldErrors: {
          EmployeeFormField.managerEmployeeId:
              'No employee has this EmployeeID.',
        },
      );
    }
  }

  Future<Employee> _save(Employee current, Map<String, Object?> fields) async {
    try {
      return await _directory.update(current: current, fields: fields);
    } on GraphException catch (e) {
      if (e.isPreconditionFailed) {
        throw EmployeeRuleException(
          'Someone else changed this employee. Reload the list and try again.',
        );
      }
      rethrow;
    }
  }

  EmployeeRuleException _alreadyRegistered() => EmployeeRuleException(
        'This Microsoft account is already registered.',
        fieldErrors: {
          EmployeeFormField.entraObjectId: 'Already registered.',
        },
      );
}
