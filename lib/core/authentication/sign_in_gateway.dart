/// What the session service needs from the sign-in code.
/// [AuthService] is the real implementation. Tests use a fake.
abstract interface class SignInGateway {
  /// True when a saved session exists and could be refreshed.
  Future<bool> trySilentSignIn();

  /// Opens the system browser and completes sign-in.
  /// Throws `AuthException` with a safe message on failure.
  Future<void> signIn();

  /// Clears the saved session and the in-memory token.
  Future<void> signOut();
}
