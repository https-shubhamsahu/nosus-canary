import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_sus/theme.dart';
import '../providers/auth_providers.dart';
import '../providers/risk_state_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/reset_password_screen.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/risk_engine_service.dart';
import '../../../../services/device_integrity_service.dart';
import '../../../onboarding/presentation/screens/get_started_screen.dart';
import '../../../onboarding/presentation/screens/welcome_screen.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../../../screens/splash_screen.dart';

class AuthGate extends ConsumerWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    // ── 1. Auth state ──────────────────────────────────────────────────────────
    return authState.when(
      data: (user) {
        // A password-recovery link grants a real (non-null) session so it
        // can call updateUser — but that session must only ever be used to
        // set a new password, never to browse in as the account holder.
        if (ref.watch(passwordRecoveryProvider)) {
          return const ResetPasswordScreen();
        }

        // Signed out. This used to render AuthScreen unconditionally, which
        // made an email field the first thing anyone ever saw — no explanation
        // of the product, and no way to try any part of it. WelcomeScreen
        // explains what this is and hands over the features that genuinely
        // need no account (Burn Notes, Burn Files, code redemption); it pushes
        // AuthScreen when the user asks for it.
        //
        // A returning user who has already seen the pitch and signed out goes
        // straight back to the form.
        if (user == null) {
          return ref.watch(welcomeSeenProvider)
              ? const AuthScreen()
              : const WelcomeScreen();
        }

        // ── 2a. Email confirmation gate ────────────────────────────────────────
        if (SupabaseService.instance.isReachable) {
          final rawUser = Supabase.instance.client.auth.currentUser;
          if (rawUser != null && rawUser.emailConfirmedAt == null) {
            return _EmailConfirmationScreen(email: user.email ?? '');
          }
        }

        // ── 2b. Risk gate (session_locked / require_reauth) ────────────────────
        // Keeps the auth-state listener that clears these flags after a
        // fresh sign-in alive for the app's lifetime — see
        // risk_reauth_acknowledger_provider's doc comment for why a plain
        // authStateProvider watch can't detect "this was a real sign-in".
        ref.watch(riskReauthAcknowledgerProvider);
        final riskState = ref.watch(riskStateProvider).value ?? RiskState.low;
        if (riskState.sessionLocked || riskState.requireReauth) {
          return _SecurityGateScreen(critical: riskState.sessionLocked);
        }

        // Fire-and-forget, deduped internally to once per app session — see
        // DeviceIntegrityService.registerDeviceSeen's doc comment for why
        // this can't run any earlier than "user is confirmed signed in".
        DeviceIntegrityService.instance.registerDeviceSeen();

        // ── 2c. Profile / Onboarding Gate ──────────────────────────────────────
        // Mock fallback mode (no credentials configured — see
        // SupabaseCredentials) has no backend to reach by design, so it must
        // not trip this gate. Only a *configured* backend that's momentarily
        // unreachable should block here.
        if (SupabaseService.instance.isConfigured &&
            !SupabaseService.instance.isReachable) {
          return _OfflineGateScreen(
            onRetry: () async {
              await SupabaseService.instance.initialize();
              ref.invalidate(authStateProvider);
            },
          );
        }

        final localCompleted = ref.watch(onboardingCompletedProvider);
        if (localCompleted) return child;

        final profileAsync = ref.watch(sessionProfileProvider);
        return profileAsync.when(
          data: (profileData) {
            if (profileData['onboarding_completed'] == true) return child;
            return const GetStartedScreen();
          },
          loading: () => const BrandSplash(),
          // A profile request can fail while a valid persisted session is
          // offline. Keep that user in the app rather than creating a login
          // flicker or signing them out.
          error: (_, _) => child,
        );
      },
      loading: () => const BrandSplash(),
      error: (error, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
        final subtle = isDark
            ? NoSusTheme.dTextSecondary
            : NoSusTheme.lTextSecondary;

        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(NoSusTheme.s24),
              child: Container(
                padding: const EdgeInsets.all(NoSusTheme.s32),
                decoration: NoSusTheme.cardDecoration(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Icon(
                        Icons.report_gmailerrorred_outlined,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: NoSusTheme.s24),
                    Text(
                      'AUTHENTICATION ERROR',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.redAccent,
                        letterSpacing: 2.0,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: NoSusTheme.s16),
                    Text(
                      error
                          .toString()
                          .replaceAll('Exception: ', '')
                          .replaceAll('AuthApiException: ', ''),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtle,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: NoSusTheme.s32),
                    Semantics(
                      button: true,
                      label: 'Retry',
                      child: GestureDetector(
                        onTap: () => ref.invalidate(authStateProvider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: fg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'RETRY',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Offline Gate (no reachable Supabase host at startup) ─────────────────────

/// Shown when [SupabaseService.isReachable] is false — replaces the old
/// unconditional dead-end block with a retry action that re-runs
/// [SupabaseService.initialize] and invalidates [authStateProvider] so
/// [AuthGate] re-evaluates the reachability check.
class _OfflineGateScreen extends StatefulWidget {
  final Future<void> Function() onRetry;
  const _OfflineGateScreen({required this.onRetry});

  @override
  State<_OfflineGateScreen> createState() => _OfflineGateScreenState();
}

class _OfflineGateScreenState extends State<_OfflineGateScreen> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    await widget.onRetry();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(NoSusTheme.s24),
            child: Container(
              padding: const EdgeInsets.all(NoSusTheme.s32),
              decoration: NoSusTheme.cardDecoration(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Icon(
                      Icons.wifi_off_outlined,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: NoSusTheme.s24),
                  Text(
                    'NETWORK CONNECTION REQUIRED',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.amber,
                      letterSpacing: 2.0,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: NoSusTheme.s16),
                  Text(
                    'The secure enclave needs a live connection to continue. Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: subtle,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: NoSusTheme.s32),
                  Semantics(
                    button: true,
                    enabled: !_isRetrying,
                    label: 'Retry',
                    child: GestureDetector(
                      onTap: _isRetrying ? null : _retry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: fg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: _isRetrying
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                )
                              : Text(
                                  'RETRY',
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Security Gate (session_locked / require_reauth) ──────────────────────────

/// Shown when the risk engine (recompute_user_risk in
/// 20260710030000_risk_engine.sql) has flagged this account as 'high' or
/// 'critical' risk. [critical] distinguishes a full lock (multiple/severe
/// signals — e.g. active instrumentation detected) from a softer
/// require-reauth prompt (fewer/lower-severity signals). Either way the
/// remedy is the same: sign out and sign back in, which
/// riskReauthAcknowledgerProvider detects and clears server-side.
class _SecurityGateScreen extends ConsumerWidget {
  final bool critical;
  const _SecurityGateScreen({required this.critical});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  critical ? Icons.gpp_bad_outlined : Icons.security_outlined,
                  size: 56,
                  color: critical ? Colors.redAccent : Colors.orangeAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  critical
                      ? 'ACCESS TEMPORARILY RESTRICTED'
                      : 'SECURITY CHECK REQUIRED',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    letterSpacing: 2.0,
                    color: critical ? Colors.redAccent : Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  critical
                      ? 'We detected unusual security signals on this account (e.g. tampering or repeated screenshot attempts). Sign back in to continue — this refreshes your session and clears the flag if the risk has passed.'
                      : 'We noticed some security signals on this account recently. For your protection, please sign in again to continue.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtle,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    button: true,
                    label: 'Sign out and re-verify',
                    child: GestureDetector(
                      onTap: () => Supabase.instance.client.auth.signOut(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: fg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'SIGN OUT & RE-VERIFY',
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Email Confirmation Holding Screen ────────────────────────────────────────

class _EmailConfirmationScreen extends ConsumerWidget {
  final String email;
  const _EmailConfirmationScreen({required this.email});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated envelope icon
                Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: fg.withValues(alpha: 0.1)),
                      ),
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        size: 40,
                        color: fg.withValues(alpha: 0.85),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.05, 1.05),
                      duration: 2000.ms,
                    ),
                const SizedBox(height: 32),
                Text(
                  'CONFIRM YOUR EMAIL',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    letterSpacing: 2.5,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'We sent a confirmation link to\n$email\n\nCheck your inbox and click the link to activate your account.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtle,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                // Check status button
                Semantics(
                  button: true,
                  label: "I've confirmed — continue",
                  child: GestureDetector(
                    onTap: () => ref.invalidate(authStateProvider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 32,
                      ),
                      decoration: BoxDecoration(
                        color: fg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "I'VE CONFIRMED — CONTINUE",
                        style: TextStyle(
                          color: isDark ? Colors.black : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sign out and try another account
                TextButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    ref.invalidate(authStateProvider);
                  },
                  child: Text(
                    'USE A DIFFERENT ACCOUNT',
                    style: TextStyle(
                      color: subtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
