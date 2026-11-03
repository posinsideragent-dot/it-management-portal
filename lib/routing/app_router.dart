import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/sign_in_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/employee_management/employee_list_page.dart';
import '../features/settings/settings_page.dart';
import '../features/task_management/task_list_page.dart';
import '../features/time_tracking/time_tracker_page.dart';
import '../services/session_state.dart';
import '../shared/layouts/app_shell.dart';
import '../state/providers.dart';

/// Route paths in one place. Do not repeat these strings in widgets.
class AppRoutes {
  const AppRoutes._();

  static const signIn = '/sign-in';
  static const dashboard = '/dashboard';
  static const employees = '/employees';
  static const tasks = '/tasks';
  static const timeTracker = '/time-tracker';
  static const settings = '/settings';
}

/// Sends people who are not signed in to the sign-in page, and sends
/// signed-in people away from it. UI redirects are for usability only.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(
    sessionControllerProvider,
    (previous, next) => refresh.value++,
  );

  final router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(sessionControllerProvider) is SessionActive;
      final atSignIn = state.matchedLocation == AppRoutes.signIn;
      if (!signedIn && !atSignIn) return AppRoutes.signIn;
      if (signedIn && atSignIn) return AppRoutes.dashboard;
      // A hidden page cannot be opened by address either.
      if (state.matchedLocation == AppRoutes.timeTracker &&
          !ref.read(appConfigProvider).showTimeTracker) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.employees,
            builder: (context, state) => const EmployeeListPage(),
          ),
          GoRoute(
            path: AppRoutes.tasks,
            builder: (context, state) => const TaskListPage(),
          ),
          GoRoute(
            path: AppRoutes.timeTracker,
            builder: (context, state) => const TimeTrackerPage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
