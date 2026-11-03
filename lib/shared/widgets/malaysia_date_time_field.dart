import 'package:fluent_ui/fluent_ui.dart';

import '../../core/utilities/malaysia_time.dart';

/// Picks a date and a time, read as Malaysia time (UTC+8).
/// [value] and [onChanged] use UTC, as everywhere in the app.
class MalaysiaDateTimeField extends StatelessWidget {
  const MalaysiaDateTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.defaultHour = 17,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;

  /// Hour used when only the date has been chosen.
  final int defaultHour;

  @override
  Widget build(BuildContext context) {
    final my = value == null ? null : toMalaysiaTime(value!);

    void emit({DateTime? date, DateTime? time}) {
      final baseDate = date ?? my ?? DateTime.now();
      final hour = time?.hour ?? my?.hour ?? defaultHour;
      final minute = time?.minute ?? my?.minute ?? 0;
      onChanged(
        malaysiaWallClockToUtc(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          hour,
          minute,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DatePicker(
          selected: my == null ? null : DateTime(my.year, my.month, my.day),
          onChanged: enabled ? (d) => emit(date: d) : null,
        ),
        TimePicker(
          selected: my == null
              ? null
              : DateTime(2000, 1, 1, my.hour, my.minute),
          onChanged: enabled ? (t) => emit(time: t) : null,
        ),
        Button(
          onPressed: enabled && value != null ? () => onChanged(null) : null,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}
