import 'package:fluent_ui/fluent_ui.dart';

import '../../core/utilities/malaysia_time.dart';

/// Picks a date only, read as a Malaysia calendar date.
/// [value] and [onChanged] use UTC, as everywhere in the app. A chosen date
/// is stored as 00:00 Malaysia time of that day.
class MalaysiaDateField extends StatelessWidget {
  const MalaysiaDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final my = value == null ? null : toMalaysiaTime(value!);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DatePicker(
          selected: my == null ? null : DateTime(my.year, my.month, my.day),
          onChanged: enabled
              ? (d) => onChanged(malaysiaWallClockToUtc(d.year, d.month, d.day))
              : null,
        ),
        Button(
          onPressed: enabled && value != null ? () => onChanged(null) : null,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}
