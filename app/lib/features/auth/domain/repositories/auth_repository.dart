import '../entities/authenticated_user.dart';

abstract interface class AuthRepository {
  AuthenticatedUser? get currentUser;

  Stream<AuthenticatedUser?> watchAuthState();

  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  });

  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();
  Future<void> signInWithGitHub();
  Future<void> signInWithPhone(String phone);
  Future<AuthenticatedUser> verifyPhoneOtp(String phone, String otp);

  /// Sends a password-reset email. Never throws for "no such account" — the
  /// caller should show the same generic confirmation either way so this
  /// can't be used to enumerate registered emails.
  Future<void> requestPasswordReset(String email);

  /// Sets a new password. Only valid while the user holds a temporary
  /// recovery session (see [AuthGate]'s password-recovery gate).
  Future<void> updatePassword(String newPassword);

  Future<void> signOut();
}
