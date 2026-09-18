import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/providers/theme_provider.dart';
import 'package:no_sus/features/auth/domain/entities/authenticated_user.dart';
import 'package:no_sus/features/auth/domain/repositories/auth_repository.dart';
import 'package:no_sus/features/auth/presentation/providers/auth_providers.dart';
import 'package:no_sus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:no_sus/features/onboarding/presentation/providers/tour_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for the two bugs that made first-run setup replay.
///
/// 1. Completion used to live only in memory, so finishing setup while the
///    backend was unreachable persisted nothing and the whole flow ran again on
///    every launch.
/// 2. Making it durable then created the opposite bug: a device-wide boolean
///    would let a *second* account signing in on the same handset skip setup,
///    because AuthGate treats the local flag as an OR against the server's
///    per-account `profiles.onboarding_completed`.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> containerFor(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(
            userId == null
                ? null
                : AuthenticatedUser(id: userId, email: '$userId@example.com'),
          ),
        ),
      ],
    );
  }

  /// authStateProvider is async, and OnboardingNotifier keys off it. Without
  /// settling it first the notifier reads a null user and the assertions below
  /// would pass for the wrong reason.
  Future<void> settleAuth(ProviderContainer container) async {
    final sub = container.listen(authStateProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(authStateProvider.future);
  }

  group('OnboardingNotifier', () {
    test('survives a restart once completed', () async {
      final first = await containerFor('user-1');
      addTearDown(first.dispose);
      await settleAuth(first);

      expect(first.read(onboardingCompletedProvider), isFalse);
      await first.read(onboardingCompletedProvider.notifier).complete();
      expect(first.read(onboardingCompletedProvider), isTrue);

      // A fresh container over the same SharedPreferences is what a relaunch
      // looks like — this is the case the in-memory notifier got wrong.
      final relaunched = await containerFor('user-1');
      addTearDown(relaunched.dispose);
      await settleAuth(relaunched);

      expect(relaunched.read(onboardingCompletedProvider), isTrue);
    });

    test(
      'does not carry over to a different account on the same device',
      () async {
        final first = await containerFor('user-1');
        addTearDown(first.dispose);
        await settleAuth(first);
        await first.read(onboardingCompletedProvider.notifier).complete();

        final second = await containerFor('user-2');
        addTearDown(second.dispose);
        await settleAuth(second);

        expect(
          second.read(onboardingCompletedProvider),
          isFalse,
          reason: 'a second account must still get first-run setup',
        );
      },
    );

    test('reset clears completion so a new account starts fresh', () async {
      final container = await containerFor('user-1');
      addTearDown(container.dispose);
      await settleAuth(container);

      await container.read(onboardingCompletedProvider.notifier).complete();
      await container.read(onboardingCompletedProvider.notifier).reset();

      expect(container.read(onboardingCompletedProvider), isFalse);
    });
  });

  group('welcomeSeenProvider', () {
    test('is device-scoped and survives a restart', () async {
      final first = await containerFor(null);
      addTearDown(first.dispose);

      expect(first.read(welcomeSeenProvider), isFalse);
      await first.read(welcomeSeenProvider.notifier).markSeen();

      final relaunched = await containerFor(null);
      addTearDown(relaunched.dispose);
      expect(relaunched.read(welcomeSeenProvider), isTrue);
    });
  });

  group('TourProgressNotifier', () {
    test('remembers dismissed tips and forgets them on reset', () async {
      final container = await containerFor('user-1');
      addTearDown(container.dispose);

      final notifier = container.read(tourProgressProvider.notifier);
      expect(notifier.hasSeen(TourSteps.workspaceTools), isFalse);

      await notifier.markSeen([TourSteps.workspaceTools]);
      expect(notifier.hasSeen(TourSteps.workspaceTools), isTrue);
      expect(
        notifier.hasSeen(TourSteps.groupsCreate),
        isFalse,
        reason: 'tips are tracked individually, not as one global flag',
      );

      // A relaunch must not re-show a dismissed tip.
      final relaunched = await containerFor('user-1');
      addTearDown(relaunched.dispose);
      expect(
        relaunched
            .read(tourProgressProvider.notifier)
            .hasSeen(TourSteps.workspaceTools),
        isTrue,
      );

      await relaunched.read(tourProgressProvider.notifier).resetAll();
      expect(
        relaunched
            .read(tourProgressProvider.notifier)
            .hasSeen(TourSteps.workspaceTools),
        isFalse,
        reason: 'Help → show tips again must actually replay them',
      );
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  final AuthenticatedUser? user;

  const _FakeAuthRepository(this.user);

  @override
  AuthenticatedUser? get currentUser => user;

  @override
  Stream<AuthenticatedUser?> watchAuthState() => Stream.value(user);

  @override
  Future<AuthenticatedUser> signIn({
    required String email,
    required String password,
  }) async => user!;

  @override
  Future<AuthenticatedUser> signUp({
    required String email,
    required String password,
  }) async => user!;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithGitHub() async {}

  @override
  Future<void> signInWithPhone(String phone) async {}

  @override
  Future<AuthenticatedUser> verifyPhoneOtp(String phone, String otp) async =>
      user!;

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> signOut() async {}
}
