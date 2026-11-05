import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/session_state.dart';
import '../../shared/layouts/page_frame.dart';
import '../../state/providers.dart';
import '../../state/ui_state.dart';

/// Shows the signed-in account and lets the user sign out.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final config = ref.watch(appConfigProvider);

    final rows = <(String, String)>[
      ('Environment', config.environment),
      if (session is SessionActive) ...[
        ('Name', session.user.name),
        ('Account', session.user.profile.userPrincipalName),
        ('Employee ID', session.user.employee.employeeId),
        ('Role', session.user.role),
      ],
    ];

    return PageFrame(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 140, child: Text(label)),
                  Text(value),
                ],
              ),
            ),
          const SizedBox(height: 8),
          ToggleSwitch(
            checked: ref.watch(themeModeProvider) == ThemeMode.dark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            content: const Text('Dark mode'),
          ),
          const SizedBox(height: 16),
          Button(
            onPressed: () => _confirmSignOut(context, ref),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).signOut();
    }
  }
}
