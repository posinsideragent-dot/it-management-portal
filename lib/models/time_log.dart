import '../core/configuration/app_config.dart';

/// IT_TimeLogs TimerStatus choice values.
enum TimerStatus {
  active('Active'),
  completed('Completed'),
  corrected('Corrected');

  const TimerStatus(this.label);
  final String label;

  static TimerStatus? tryParse(String value) {
    for (final s in TimerStatus.values) {
      if (s.label == value) return s;
    }
    return null;
  }
}

/// One work segment: from Start (or Resume) to Pause or End.
/// A row is Active while its timer runs. Dates are UTC.
class TimeLog {
  const TimeLog({
    required this.itemId,
    required this.etag,
    required this.timeLogCode,
    required this.employeeId,
    required this.taskCode,
    required this.startUtc,
    required this.status,
    this.endUtc,
    this.durationMinutes,
    this.activeTimerKey = '',
    this.activityDescription = '',
    this.workResult = '',
    this.isDeleted = false,
  });

  final String itemId;

  /// Sent as If-Match on updates.
  final String etag;
  final String timeLogCode;
  final String employeeId;
  final String taskCode;
  final DateTime startUtc;
  final DateTime? endUtc;
  final double? durationMinutes;
  final TimerStatus status;
  final String activeTimerKey;
  final String activityDescription;
  final String workResult;

  /// Logical deletion only. Deleted rows are ignored in totals.
  final bool isDeleted;

  bool get isActive => status == TimerStatus.active;

  /// The key that makes a second active timer impossible.
  static String activeKeyFor(String employeeId) => 'ACTIVE|$employeeId';

  /// Minutes worked. A running segment counts up to [nowUtc].
  double minutesAt(DateTime nowUtc) {
    if (isDeleted) return 0;
    if (isActive) {
      final seconds = nowUtc.difference(startUtc).inSeconds;
      return seconds <= 0 ? 0 : seconds / 60;
    }
    return durationMinutes ?? 0;
  }

  /// [item] is a Graph list item requested with $expand=fields.
  factory TimeLog.fromGraphItem(Map<String, dynamic> item) {
    final f = (item['fields'] as Map<String, dynamic>?) ?? const {};
    String text(String key) => (f[key] ?? '').toString();
    return TimeLog(
      itemId: item['id'].toString(),
      etag: (item['eTag'] ?? item['@odata.etag'] ?? '').toString(),
      timeLogCode: text(SpFields.timeLogCode),
      employeeId: text(SpFields.employeeId),
      taskCode: text(SpFields.taskCode),
      startUtc: _utc(f[SpFields.startTimeUtc]) ?? DateTime.utc(1970),
      endUtc: _utc(f[SpFields.endTimeUtc]),
      durationMinutes: f[SpFields.durationMinutes] is num
          ? (f[SpFields.durationMinutes] as num).toDouble()
          : null,
      status: TimerStatus.tryParse(text(SpFields.timerStatus)) ??
          TimerStatus.completed,
      activeTimerKey: text(SpFields.activeTimerKey),
      activityDescription: text(SpFields.activityDescription),
      workResult: text(SpFields.workResult),
      isDeleted: f[SpFields.isDeleted] == true,
    );
  }
}

DateTime? _utc(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toUtc();
