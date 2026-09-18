import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../../../analytics/data/analytics_service.dart';
import '../../../notifications/data/push_service.dart';

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      AnalyticsService.instance.log(AnalyticsEvent.signinCompleted);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> signUp(String email, String password) async {
    state = const AsyncValue.loading();
    // Logged before the call, not after: the gap between "started" and
    // "completed" is exactly the drop-off this funnel exists to measure, and a
    // signup that fails would otherwise be invisible.
    AnalyticsService.instance.log(AnalyticsEvent.signupStarted);
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password);
      AnalyticsService.instance.log(AnalyticsEvent.signupCompleted);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      AnalyticsService.instance.log(AnalyticsEvent.signinCompleted);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> signInWithGitHub() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).signInWithGitHub();
      AnalyticsService.instance.log(AnalyticsEvent.signinCompleted);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> signInWithPhone(String phone) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).signInWithPhone(phone);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> verifyPhoneOtp(String phone, String otp) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).verifyPhoneOtp(phone, otp);
      AnalyticsService.instance.log(AnalyticsEvent.signinCompleted);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      // Before the session is torn down, not after: unregister_device_token is
      // scoped by auth.uid(), so once signed out the delete matches nothing and
      // this handset would keep receiving the previous account's notifications
      // until someone else's registration happened to overwrite the row.
      await PushService.instance.releaseCurrentDevice();

      await ref.read(authRepositoryProvider).signOut();
      // Onboarding completion is no longer reset here. It is now recorded
      // against the account that completed it (see OnboardingNotifier), so a
      // different account signing in on this device still gets first-run setup,
      // and this one does not repeat it — which is what the old unconditional
      // reset() got wrong once the flag became durable.
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Always resolves to loading->data on success — callers should show the
  /// same generic confirmation regardless of whether the account exists, so
  /// this can't be used to enumerate registered emails. Real failures (e.g.
  /// network down) still surface as an error state.
  Future<void> requestPasswordReset(String email) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
