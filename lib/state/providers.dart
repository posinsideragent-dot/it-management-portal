import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/authentication/auth_service.dart';
import '../core/configuration/app_config.dart';
import '../data/api/graph_client.dart';
import '../data/repositories/daily_report_repository.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/time_log_repository.dart';
import '../models/app_user.dart';
import '../models/employee.dart';
import '../services/daily_report_service.dart';
import '../services/employee_service.dart';
import '../services/session_service.dart';
import '../services/session_state.dart';
import '../services/task_service.dart';
import '../services/time_tracking_service.dart';

/// Which environment the app talks to. Change here to build for PROD later.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.dev);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(appConfigProvider)),
);

final graphClientProvider = Provider<GraphClient>(
  (ref) => GraphClient(ref.watch(authServiceProvider)),
);

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepository(
    ref.watch(graphClientProvider),
    ref.watch(appConfigProvider),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(graphClientProvider)),
);

final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(
    auth: ref.watch(authServiceProvider),
    profiles: ref.watch(profileRepositoryProvider),
    employees: ref.watch(employeeRepositoryProvider),
  ),
);

/// Holds the current [SessionState] for the UI.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    // Look for a saved session right after startup.
    Future.microtask(_restore);
    return const SessionChecking();
  }

  SessionService get _service => ref.read(sessionServiceProvider);

  Future<void> _restore() async {
    state = await _service.restore();
  }

  Future<void> signIn() async {
    state = const SessionSigningIn();
    state = await _service.signIn();
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const SessionSignedOut();
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

// --- Employees module ---

/// The signed-in person, or null when nobody is signed in.
final currentUserProvider = Provider<AppUser?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return session is SessionActive ? session.user : null;
});

final employeeDirectoryProvider = Provider<EmployeeDirectory>(
  (ref) => ref.watch(employeeRepositoryProvider),
);

final employeeServiceProvider = Provider<EmployeeService>(
  (ref) => EmployeeService(ref.watch(employeeDirectoryProvider)),
);

// --- Tasks module ---

final taskDirectoryProvider = Provider<TaskDirectory>(
  (ref) => TaskRepository(
    ref.watch(graphClientProvider),
    ref.watch(appConfigProvider),
  ),
);

final taskServiceProvider = Provider<TaskService>(
  (ref) => TaskService(
    ref.watch(taskDirectoryProvider),
    ref.watch(employeeDirectoryProvider),
  ),
);

// --- Daily Reports ---

final dailyReportDirectoryProvider = Provider<DailyReportDirectory>(
  (ref) => DailyReportRepository(
    ref.watch(graphClientProvider),
    ref.watch(appConfigProvider),
  ),
);

final dailyReportServiceProvider = Provider<DailyReportService>(
  (ref) => DailyReportService(ref.watch(dailyReportDirectoryProvider)),
);

// --- Time Tracker ---

final timeLogDirectoryProvider = Provider<TimeLogDirectory>(
  (ref) => TimeLogRepository(
    ref.watch(graphClientProvider),
    ref.watch(appConfigProvider),
  ),
);

final timeTrackingServiceProvider = Provider<TimeTrackingService>(
  (ref) => TimeTrackingService(ref.watch(timeLogDirectoryProvider)),
);

/// Active employees for the "assigned to" list and for showing names.
/// Reads at most 10 pages. Refreshes when the signed-in person changes.
final activeEmployeesProvider = FutureProvider<List<Employee>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(employeeServiceProvider).listActive();
});
