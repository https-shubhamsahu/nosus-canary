import 'package:supabase_flutter/supabase_flutter.dart';

/// Distinguishes a dead session from a transient failure.
///
/// A cached JWT whose *access* token has expired is normal — GoTrue will
/// refresh it. Signing the user out because `getUser(expiredAccessToken)`
/// threw is what made reopening the app feel like a logout.
class SessionRecovery {
  const SessionRecovery._();

  /// True only for errors that mean the refresh token itself is unusable
  /// (revoked, user deleted, corrupted storage). Network blips, 5xx, and
  /// "JWT expired" on the access token are not permanent.
  static bool isPermanentAuthFailure(Object error) {
    if (error is! AuthException) return false;
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();
    if (code == 'refresh_token_not_found' ||
        code == 'user_not_found' ||
        code == 'session_not_found' ||
        code == 'invalid_refresh_token') {
      return true;
    }
    return message.contains('refresh_token_not_found') ||
        message.contains('invalid refresh token') ||
        message.contains('user not found') ||
        (message.contains('refresh') && message.contains('not found'));
  }

  /// If a session is already expired, ask GoTrue to refresh it.
  ///
  /// Never signs out on network errors. Only clears local state when the
  /// server says the refresh token is dead — otherwise the next launch
  /// (or the next successful refresh) still has a valid session.
  static Future<void> recoverIfNeeded(GoTrueClient auth) async {
    final session = auth.currentSession;
    if (session == null) return;
    if (!session.isExpired) return;
    try {
      await auth.refreshSession();
    } catch (error) {
      if (isPermanentAuthFailure(error)) {
        await auth.signOut();
      }
    }
  }
}
