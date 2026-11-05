import '../models/app_user.dart';

/// Where the sign-in process is. The UI only reads this.
sealed class SessionState {
  const SessionState();
}

/// Looking for a saved session at startup.
final class SessionChecking extends SessionState {
  const SessionChecking();
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

/// The browser is open and we are waiting for the user.
final class SessionSigningIn extends SessionState {
  const SessionSigningIn();
}

/// Signed in to Microsoft but not allowed to use ITDMP.
/// The saved session has already been cleared.
final class SessionBlocked extends SessionState {
  const SessionBlocked(this.message);
  final String message;
}

/// Something went wrong (network, timeout, server). The user can try again.
final class SessionFailed extends SessionState {
  const SessionFailed(this.message);
  final String message;
}

final class SessionActive extends SessionState {
  const SessionActive(this.user);
  final AppUser user;
}
