import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/auth/domain/entities/authenticated_user.dart';
import 'package:no_sus/features/auth/domain/repositories/auth_repository.dart';
import 'package:no_sus/features/auth/presentation/providers/auth_providers.dart';

void main() {
  test('auth state provider reads from the injected repository', () async {
    const user = AuthenticatedUser(id: 'user-1', email: 'student@example.com');
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(const _FakeAuthRepository(user)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(authStateProvider, (_, _) {});
    addTearDown(subscription.close);

    final result = await container.read(authStateProvider.future);

    expect(result?.id, user.id);
    expect(result?.email, user.email);
  });
}

class _FakeAuthRepository implements AuthRepository {
  final AuthenticatedUser user;

  const _FakeAuthRepository(this.user);

  @override
  AuthenticatedUser get currentUser => user;

  @override
  Stream<AuthenticatedUser?> watchAuthState() => Stream.value(user);

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async {
    return user;
  }

  @override
  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  }) async {
    return user;
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithGitHub() async {}

  @override
  Future<void> signInWithPhone(String phone) async {}

  @override
  Future<AuthenticatedUser> verifyPhoneOtp(String phone, String otp) async {
    return user;
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> signOut() async {}
}
