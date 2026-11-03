/// Estimate versus actual (spec 11.3).
///
/// VarianceHours = Actual - Estimated
/// VariancePercentage = (Actual - Estimated) / Estimated * 100
/// There is no percentage when the estimate is zero.
class TaskVariance {
  const TaskVariance({required this.hours, required this.percent});

  final double hours;

  /// Null when the estimate is zero.
  final double? percent;

  factory TaskVariance.compute({
    required double estimatedHours,
    required double actualHours,
  }) {
    final hours = actualHours - estimatedHours;
    return TaskVariance(
      hours: hours,
      percent: estimatedHours == 0 ? null : hours / estimatedHours * 100,
    );
  }
}
