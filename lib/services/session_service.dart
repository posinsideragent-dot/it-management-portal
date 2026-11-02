import '../core/authentication/auth_service.dart' show AuthException;
import '../core/authentication/sign_in_gateway.dart';
import '../data/api/graph_client.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../models/app_user.dart';
import 'session_state.dart';

/// Sign-in rules (Phase 1, step 7).
///
/// 1. Sign in with Microsoft.
/// 2. Read who the user is.
/// 3. Find that Object ID in IT_Employees.
/// 4. Block unknown and inactive users, and clear their saved session.
///
/// This is a usability check. SharePoint permissions are the real security.
class SessionService {
  SessionService({
    required SignInGateway auth,
    required ProfileSource profiles,
    required EmployeeLookup employees,
  })  : _auth = auth,
        _profiles = profiles,
        _employees = employees;

  final SignInGateway _auth;
  final ProfileSource _profiles;
  final EmployeeLookup _employees;

  /// Called at startup. Uses the saved session if there is one.
  Future<SessionState> restore() async {
    final hasSession = await _auth.trySilentSignIn();
    if (!hasSession) return const SessionSignedOut();
    return _resolveIdentity();
  }

  /// Called when the user clicks Sign in.
  Future<SessionState> signIn() async {
    try {
      await _auth.signIn();
    } on AuthException catch (e) {
      return SessionFailed(e.message);
    }
    return _resolveIdentity();
  }

  Future<void> signOut() => _auth.signOut();

  Future<SessionState> _resolveIdentity() async {
    try {
      final profile = await _profiles.fetchMe();
      final employee = await _employees.findByEntraObjectId(profile.objectId);
      if (employee == null) {
        return _block(
          '${profile.userPrincipalName} is not registered in ITDMP. '
          'Ask IT to add you to the employee list.',
        );
      }
      if (!employee.isActive) {
        return _block('Your ITDMP account is inactive. Contact IT.');
      }
      return SessionActive(AppUser(profile: profile, employee: employee));
    } on GraphException catch (e) {
      if (e.isForbidden) {
        return _block(
          'You do not have permission to use ITDMP. '
          'Ask IT to add your account to the ITDMP site.',
        );
      }
      return SessionFailed(e.userMessage);
    } on AuthException catch (e) {
      return SessionFailed(e.message);
    }
  }

  Future<SessionState> _block(String message) async {
    await _auth.signOut();
    return SessionBlocked(message);
  }
}
