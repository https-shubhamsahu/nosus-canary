import 'dart:async';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  static AuthenticatedUser? _staticUser;
  static final StreamController<AuthenticatedUser?> _authStateController =
      StreamController<AuthenticatedUser?>.broadcast();

  const MockAuthRepository();

  @override
  AuthenticatedUser? get currentUser => _staticUser;

  @override
  Stream<AuthenticatedUser?> watchAuthState() async* {
    yield _staticUser;
    yield* _authStateController.stream;
  }

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _staticUser = AuthenticatedUser(
      id: 'me',
      email: email,
    );
    _authStateController.add(_staticUser);
    return _staticUser!;
  }

  @override
  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _staticUser = AuthenticatedUser(
      id: 'me',
      email: email,
    );
    _authStateController.add(_staticUser);
    return _staticUser!;
  }

  @override
  Future<void> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _staticUser = const AuthenticatedUser(
      id: 'mock-google-user',
      email: 'student.google@nosus.app',
    );
    _authStateController.add(_staticUser);
  }

  @override
  Future<void> signInWithGitHub() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _staticUser = const AuthenticatedUser(
      id: 'mock-github-user',
      email: 'student.github@nosus.app',
    );
    _authStateController.add(_staticUser);
  }

  @override
  Future<void> signInWithPhone(String phone) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<AuthenticatedUser> verifyPhoneOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _staticUser = AuthenticatedUser(
      id: 'mock-phone-user',
      email: phone.isNotEmpty ? '$phone@nosus.app' : 'student.phone@nosus.app',
    );
    _authStateController.add(_staticUser);
    return _staticUser!;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _staticUser = null;
    _authStateController.add(null);
  }
}
