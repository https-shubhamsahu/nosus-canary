import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/risk_engine_service.dart';
import 'auth_providers.dart';

/// Live risk state for the current user (score/tier/watermark
/// intensity/lock flags), recomputed server-side by
/// recompute_user_risk() every time a scored security event lands in
/// audit_logs or device_integrity_events — see
/// supabase/migrations/20260710030000_risk_engine.sql. Streams via
/// Supabase Realtime so a mid-session escalation (e.g. repeated
/// screenshot attempts) reaches [AuthGate] without waiting for a restart.
final riskStateProvider = StreamProvider<RiskState>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(RiskState.low);
  return RiskEngineService.instance.watch(user.id);
});

/// Clears a require_reauth/session_locked gate the moment the user
/// completes a genuine interactive sign-in — not on a restored session at
/// cold start, which is why this listens for [AuthChangeEvent.signedIn]
/// specifically rather than watching [authStateProvider] (whose
/// AuthenticatedUser abstraction doesn't carry the event type). Mirrors
/// [PasswordRecoveryNotifier]'s listener pattern in auth_providers.dart.
///
/// Without this, a locked user who signs back out and back in would see
/// the exact same lock screen again forever — recompute_user_risk() only
/// re-runs on a NEW security event, so the flags never clear on their own.
final riskReauthAcknowledgerProvider = Provider<void>((ref) {
  // Mock fallback mode: supabaseClientProvider throws by design (no backend
  // to hold a real session), and there's no server-side risk state to
  // acknowledge against anyway.
  if (!SupabaseService.instance.isConfigured || !SupabaseService.instance.isReachable) {
    return;
  }
  final sub = ref
      .watch(supabaseClientProvider)
      .auth
      .onAuthStateChange
      .listen((state) {
    if (state.event == AuthChangeEvent.signedIn) {
      RiskEngineService.instance.acknowledgeReauth();
    }
  });
  ref.onDispose(sub.cancel);
});
