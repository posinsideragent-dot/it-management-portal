import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/session_state.dart';
import '../../shared/layouts/page_frame.dart';
import '../../state/providers.dart';

/// Placeholder dashboard. Real cards arrive with the modules, after the gate.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final name = session is SessionActive ? session.user.name : '';
    final role = session is SessionActive ? session.user.role : '';

    return PageFrame(
      title: 'Dashboard',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _InfoCard(title: 'Signed in as', value: name, caption: role),
          const _InfoCard(
            title: 'Tasks',
            value: '-',
            caption: 'Coming after the Phase 1 gate',
          ),
          const _InfoCard(
            title: 'Hours today',
            value: '-',
            caption: 'Coming after the Phase 1 gate',
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.caption,
  });

  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return SizedBox(
      width: 260,
      child: Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: typography.bodyStrong),
            const SizedBox(height: 8),
            Text(value, style: typography.subtitle),
            const SizedBox(height: 4),
            Text(caption),
          ],
        ),
      ),
    );
  }
}
