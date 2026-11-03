import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/authentication/auth_service.dart';
import '../core/configuration/app_config.dart';
import '../data/api/graph_client.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../services/session_service.dart';
import '../services/session_state.dart';

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
