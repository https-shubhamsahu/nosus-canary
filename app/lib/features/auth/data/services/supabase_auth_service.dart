import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/debug_logger.dart';

class SupabaseAuthService {
  final SupabaseClient _client;

  const SupabaseAuthService(this._client);

  User? get currentUser => _client.auth.currentUser;

  Stream<User?> watchUser() {
    late final StreamController<User?> controller;
    StreamSubscription<AuthState>? subscription;

    controller = StreamController<User?>(
      onListen: () {
        // Subscribe before emitting the cached session so an auth event that
        // lands during restore cannot be missed. `currentUser` comes from the
        // SDK's persistent storage and gives AuthGate an immediate answer.
        subscription = _client.auth.onAuthStateChange.listen(
          (state) {
            debugLog(
              'NO SUS Auth State Changed: event=${state.event}, '
              'hasSession=${state.session != null}',
            );
            controller.add(state.session?.user);
          },
          onError: (Object error, StackTrace stackTrace) {
            // Auth refresh can fail while the device is offline. Keep the
            // cached session rather than turning a transient network problem
            // into a forced logout or an unhandled zone exception.
            debugLog('NO SUS Auth State Error: $error');
          },
        );
        controller.add(currentUser);
      },
      onCancel: () => subscription?.cancel(),
    );

    return controller.stream;
  }

  Future<User> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(response);
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        throw const AuthException(
          'You are not a registered user, try registration instead, or check your password.',
        );
      }
      rethrow;
    }
  }

  Future<User> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return _requireUser(response);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.nosus://login-callback',
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  Future<void> signInWithGitHub() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: kIsWeb ? null : 'io.supabase.nosus://login-callback',
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
  }

  Future<void> signInWithPhone(String phone) async {
    await _client.auth.signInWithOtp(phone: phone.trim());
  }

  Future<User> verifyPhoneOtp(String phone, String otp) async {
    final response = await _client.auth.verifyOTP(
      phone: phone.trim(),
      token: otp.trim(),
      type: OtpType.sms,
    );
    return _requireUser(response);
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? null : 'io.supabase.nosus://login-callback',
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _client.auth.signOut();

  User _requireUser(AuthResponse response) {
    final user = response.user;
    if (user == null) {
      throw StateError('Supabase authentication returned no user.');
    }
    return user;
  }
}
