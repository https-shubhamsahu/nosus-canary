import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Whether first-run setup has been completed, by the account currently signed
/// in, on this device.
///
/// Backed by SharedPreferences, not just memory. The previous implementation
/// was a plain `Notifier<bool>` whose `build()` returned `false`, so the only
/// durable record of completion was `profiles.onboarding_completed`, written by
/// the last onboarding step — and that write was skipped entirely whenever
/// `SupabaseService.isReachable` was false. Net effect: finish onboarding on a
/// flaky connection (or in mock fallback mode, which has no backend by design)
/// and the whole flow replayed on every single launch, forever.
///
/// Stores the completing account's id rather than a bare `true`. A device-wide
/// boolean would make a *second* account signing in on the same handset skip
/// setup entirely, because [AuthGate] treats the local flag as an OR against
/// the server's `profiles.onboarding_completed`, which is false for that new
/// account. Comparing ids gets both cases right without a sign-out hook.
///
/// Reads are synchronous off the pre-warmed prefs instance so [AuthGate] never
/// flashes setup at a returning user while an async read settles.
class OnboardingNotifier extends Notifier<bool> {
  static const _key = 'nosus_onboarding_completed_uid';

  /// Used when there is no session to attribute completion to — mock fallback
  /// mode. AuthGate only reaches first-run setup with a non-null user, so this
  /// is a safety net rather than a normal path.
  static const _localSentinel = '_local';

  String get _currentId =>
      ref.watch(authStateProvider).value?.id ?? _localSentinel;

  @override
  bool build() {
    try {
      final stored = ref.watch(sharedPreferencesProvider).getString(_key);
      return stored != null && stored == _currentId;
    } catch (_) {
      return false;
    }
  }

  Future<void> complete() async {
    state = true;
    try {
      await ref.read(sharedPreferencesProvider).setString(_key, _currentId);
    } catch (_) {}
  }

  Future<void> reset() async {
    state = false;
    try {
      await ref.read(sharedPreferencesProvider).remove(_key);
    } catch (_) {}
  }
}

final onboardingCompletedProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

/// Whether the signed-out welcome/explore surface has been seen on this device.
///
/// Separate from [onboardingCompletedProvider] on purpose: the welcome surface
/// is pre-auth and per-device, first-run setup is post-auth and per-account.
/// Someone who explores as a guest, signs up, then signs out should not be
/// re-pitched the intro.
class WelcomeSeenNotifier extends Notifier<bool> {
  static const _key = 'nosus_welcome_seen';

  @override
  bool build() {
    try {
      return ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    if (state) return;
    state = true;
    try {
      await ref.read(sharedPreferencesProvider).setBool(_key, true);
    } catch (_) {}
  }

  Future<void> reset() async {
    state = false;
    try {
      await ref.read(sharedPreferencesProvider).remove(_key);
    } catch (_) {}
  }
}

final welcomeSeenProvider = NotifierProvider<WelcomeSeenNotifier, bool>(
  WelcomeSeenNotifier.new,
);

/// Opt-in to the TSEC, Kandivali community during first-run setup.
///
/// This is now a real choice. `handle_new_user()` used to force-join every new
/// account worldwide to TSEC regardless of the answer, which made this toggle
/// decorative — see 20260727000000_private_group_boundary.sql.
class TsecCommunityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final tsecCommunityProvider = NotifierProvider<TsecCommunityNotifier, bool>(
  TsecCommunityNotifier.new,
);
