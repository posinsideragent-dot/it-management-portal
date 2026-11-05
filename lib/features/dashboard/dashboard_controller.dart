import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard.dart';
import '../../state/providers.dart';

/// Loads the dashboard for the signed-in person. Holds no rules: they are in
/// DashboardBuilder. Call `ref.invalidate(dashboardProvider)` to reload.
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('The dashboard needs a signed-in user.');
  }
  return ref.watch(dashboardServiceProvider).load(user);
});
