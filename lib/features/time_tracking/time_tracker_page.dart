import 'package:fluent_ui/fluent_ui.dart';

import '../../shared/layouts/page_frame.dart';

/// Placeholder. The real timer (start, pause, resume, end, recovery after
/// restart) is built after the Phase 1 gate. See spec section 10.
class TimeTrackerPage extends StatelessWidget {
  const TimeTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageFrame(
      title: 'Time Tracker',
      child: InfoBar(
        title: Text('Not built yet'),
        content: Text('The time tracker comes after the Phase 1 checks pass.'),
        isLong: true,
      ),
    );
  }
}
