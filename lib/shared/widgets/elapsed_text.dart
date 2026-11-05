import 'package:fluent_ui/fluent_ui.dart';

/// Shows how long it has been since [startUtc], as `01:23:45`, and updates
/// every second. The value is worked out from the start time on every tick,
/// so it stays right after a restart or a sleep.
class ElapsedText extends StatelessWidget {
  const ElapsedText({super.key, required this.startUtc, this.style});

  final DateTime startUtc;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) =>
          Text(formatElapsed(DateTime.now().toUtc().difference(startUtc)), style: style),
    );
  }
}

/// `01:23:45`. Negative durations show as zero.
String formatElapsed(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(total ~/ 3600)}:${two(total % 3600 ~/ 60)}:${two(total % 60)}';
}

/// `1 h 05 min`, or `12 min`.
String formatMinutes(double minutes) {
  final m = minutes.round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
}
