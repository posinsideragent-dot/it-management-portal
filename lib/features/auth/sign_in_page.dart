import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/session_state.dart';
import '../../state/providers.dart';

/// Shows every sign-in state: checking, waiting for browser, blocked,
/// failed and signed out. No business rules here.
class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final config = ref.watch(appConfigProvider);
    final busy = session is SessionChecking || session is SessionSigningIn;

    return ScaffoldPage(
      content: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IT & Development Management Portal',
                  style: FluentTheme.of(context).typography.title,
                ),
                const SizedBox(height: 4),
                Text('Environment: ${config.environment}'),
                const SizedBox(height: 20),
                _statusArea(session),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () =>
                          ref.read(sessionControllerProvider.notifier).signIn(),
                  child: const Text('Sign in with Microsoft'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusArea(SessionState session) {
    return switch (session) {
      SessionChecking() => const _Busy('Checking for a saved session...'),
      SessionSigningIn() =>
        const _Busy('Complete the sign-in in your browser.'),
      SessionBlocked(:final message) =>
        InfoBar(title: const Text('Access denied'), content: Text(message),
            severity: InfoBarSeverity.warning, isLong: true),
      SessionFailed(:final message) =>
        InfoBar(title: const Text('Sign-in failed'), content: Text(message),
            severity: InfoBarSeverity.error, isLong: true),
      SessionSignedOut() || SessionActive() =>
        const Text('Sign in with your company Microsoft account.'),
    };
  }
}

class _Busy extends StatelessWidget {
  const _Busy(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const SizedBox(width: 20, height: 20, child: ProgressRing(strokeWidth: 3)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      );
}
