import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/graph_client.dart';
import '../../models/app_role.dart';
import '../../models/employee.dart';
import '../../services/employee_access.dart';
import '../../services/employee_service.dart';
import '../../shared/layouts/page_frame.dart';
import '../../state/providers.dart';
import 'employee_form_dialog.dart';
import 'employee_list_controller.dart';
import 'employee_list_state.dart';

/// Employees table with search, filters, add, edit and deactivate.
/// Managers (Management, Admin) get the action buttons. Others read only.
class EmployeeListPage extends ConsumerWidget {
  const EmployeeListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employeeListControllerProvider);
    final user = ref.watch(currentUserProvider);
    final access = user == null
        ? const EmployeeAccess(AppRole.employee)
        : EmployeeAccess.forUser(user);

    return PageFrame(
      title: 'Employees',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Toolbar(state: state, access: access),
          const SizedBox(height: 12),
          Expanded(child: _Body(state: state, access: access)),
        ],
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.state, required this.access});

  final EmployeeListState state;
  final EmployeeAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(employeeListControllerProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextBox(
            placeholder: 'Search loaded rows',
            onChanged: controller.setSearch,
          ),
        ),
        ComboBox<ActiveFilter>(
          value: state.activeFilter,
          items: [
            for (final f in ActiveFilter.values)
              ComboBoxItem<ActiveFilter>(value: f, child: Text(f.label)),
          ],
          onChanged: (f) {
            if (f != null) controller.setActiveFilter(f);
          },
        ),
        if (access.canSeeDetails)
          ComboBox<String>(
            value: state.roleFilter ?? _allRoles,
            items: [
              const ComboBoxItem<String>(
                value: _allRoles,
                child: Text('All roles'),
              ),
              for (final r in AppRole.labels)
                ComboBoxItem<String>(value: r, child: Text(r)),
            ],
            onChanged: (r) => controller.setRoleFilter(r == _allRoles ? null : r),
          ),
        Button(onPressed: controller.load, child: const Text('Refresh')),
        if (access.canManage)
          FilledButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => const EmployeeFormDialog(),
            ),
            child: const Text('Add employee'),
          ),
      ],
    );
  }

  static const _allRoles = '__all__';
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.access});

  final EmployeeListState state;
  final EmployeeAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(employeeListControllerProvider.notifier);

    switch (state.status) {
      case LoadStatus.loading:
        return const Center(child: ProgressRing());
      case LoadStatus.failed:
        return Align(
          alignment: Alignment.topLeft,
          child: InfoBar(
            title: const Text('Could not load employees'),
            content: Text(state.errorMessage ?? 'Unknown error.'),
            severity: InfoBarSeverity.error,
            isLong: true,
            action: Button(
              onPressed: controller.load,
              child: const Text('Try again'),
            ),
          ),
        );
      case LoadStatus.ready:
        break;
    }

    final rows = state.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoBar(
              title: Text(state.errorMessage!),
              severity: InfoBarSeverity.warning,
            ),
          ),
        _HeaderRow(access: access),
        const Divider(),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    state.items.isEmpty
                        ? 'No employees found.'
                        : 'No loaded employee matches the filters.'
                            '${state.hasMore ? ' Load more to search further.' : ''}',
                  ),
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) =>
                      _EmployeeRow(employee: rows[i], access: access),
                ),
        ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: state.loadingMore
                ? const ProgressRing()
                : Button(
                    onPressed: controller.loadMore,
                    child: const Text('Load more'),
                  ),
          ),
      ],
    );
  }
}

/// Column widths (flex) shared by the header and the rows.
List<(String, int)> _columns(EmployeeAccess access) => [
      if (access.canSeeDetails) ('ID', 1),
      ('Name', 2),
      if (access.canSeeDetails) ('Email', 3),
      ('Job title', 2),
      ('Department', 2),
      if (access.canSeeDetails) ('Role', 2),
      if (access.canSeeDetails) ('Status', 1),
      if (access.canManage) ('', 3),
    ];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.access});

  final EmployeeAccess access;

  @override
  Widget build(BuildContext context) {
    final style = FluentTheme.of(context).typography.bodyStrong;
    return Row(
      children: [
        for (final (title, flex) in _columns(access))
          Expanded(flex: flex, child: Text(title, style: style)),
      ],
    );
  }
}

class _EmployeeRow extends ConsumerWidget {
  const _EmployeeRow({required this.employee, required this.access});

  final Employee employee;
  final EmployeeAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isSelf = user?.employee.employeeId == employee.employeeId;

    Widget cell(int flex, String text) => Expanded(
          flex: flex,
          child: Text(text, overflow: TextOverflow.ellipsis),
        );

    final cols = _columns(access);
    var i = 0;
    int flexOf() => cols[i++].$2;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (access.canSeeDetails) cell(flexOf(), employee.employeeId),
          cell(flexOf(), employee.name),
          if (access.canSeeDetails) cell(flexOf(), employee.email),
          cell(flexOf(), employee.jobTitle),
          cell(flexOf(), employee.department),
          if (access.canSeeDetails) cell(flexOf(), employee.appRole),
          if (access.canSeeDetails)
            Expanded(
              flex: flexOf(),
              child: Text(
                employee.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: employee.isActive ? Colors.green : Colors.grey,
                ),
              ),
            ),
          if (access.canManage)
            Expanded(
              flex: flexOf(),
              child: Wrap(
                spacing: 8,
                children: [
                  Button(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => EmployeeFormDialog(existing: employee),
                    ),
                    child: const Text('Edit'),
                  ),
                  Button(
                    onPressed: isSelf && employee.isActive
                        ? null
                        : () => _confirmToggle(context, ref),
                    child: Text(employee.isActive ? 'Deactivate' : 'Reactivate'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmToggle(BuildContext context, WidgetRef ref) async {
    final deactivate = employee.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(deactivate ? 'Deactivate employee?' : 'Reactivate employee?'),
        content: Text(
          deactivate
              ? '${employee.name} will no longer be able to use ITDMP. '
                  'Their history is kept.'
              : '${employee.name} will be able to use ITDMP again.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(deactivate ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(employeeListControllerProvider.notifier)
          .setActive(employee, active: !deactivate);
    } on EmployeeRuleException catch (e) {
      if (context.mounted) await _showError(context, e.message);
    } on GraphException catch (e) {
      if (context.mounted) await _showError(context, e.userMessage);
    }
  }

  Future<void> _showError(BuildContext context, String message) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Could not save'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
}
