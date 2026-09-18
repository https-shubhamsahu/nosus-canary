import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/supabase_auth_service.dart';
import '../../../../core/utils/debug_logger.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseAuthService _service;

  const SupabaseAuthRepository(this._service);

  @override
  AuthenticatedUser? get currentUser {
    final user = _service.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Stream<AuthenticatedUser?> watchAuthState() {
    return _service.watchUser().handleError((error, stackTrace) {
      // Log the error for diagnostic visibility
      debugLog('NO SUS Auth Stream Error: $error');
      // Swallow the error to prevent authStateProvider from terminating/entering
      // an AsyncValue.error state, which displays the blocking AuthGate error screen.
    }).map(
      (user) => user == null ? null : _mapUser(user),
    );
  }

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    return _mapUser(await _service.signIn(email: email, password: password));
  }

  @override
  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  }) async {
    return _mapUser(await _service.signUp(email: email, password: password));
  }

  @override
  Future<void> signInWithGoogle() => _service.signInWithGoogle();

  @override
  Future<void> signInWithGitHub() => _service.signInWithGitHub();

  @override
  Future<void> signInWithPhone(String phone) => _service.signInWithPhone(phone);

  @override
  Future<AuthenticatedUser> verifyPhoneOtp(String phone, String otp) async {
    final user = await _service.verifyPhoneOtp(phone, otp);
    return _mapUser(user);
  }

  @override
  Future<void> requestPasswordReset(String email) => _service.requestPasswordReset(email);

  @override
  Future<void> updatePassword(String newPassword) => _service.updatePassword(newPassword);

  @override
  Future<void> signOut() => _service.signOut();

  AuthenticatedUser _mapUser(User user) {
    return AuthenticatedUser(id: user.id, email: user.email);
  }
}
