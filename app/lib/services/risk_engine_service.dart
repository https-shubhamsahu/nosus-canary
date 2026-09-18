import 'package:flutter/foundation.dart';
import '../core/utils/debug_logger.dart';
import 'supabase_service.dart';

/// Mirrors a row of `public.user_risk_state` (see
/// supabase/migrations/20260710030000_risk_engine.sql). The score/tier are
/// computed entirely server-side by recompute_user_risk() — this class is
/// just a read model, never a place that decides risk on-device (a
/// compromised client could lie about its own risk otherwise).
@immutable
class RiskState {
  final int score;
  final String tier; // low | elevated | high | critical
  final String watermarkIntensity; // normal | increased | maximum
  final bool sessionLocked;
  final bool requireReauth;
  final Map<String, dynamic> breakdown;

  const RiskState({
    required this.score,
    required this.tier,
    required this.watermarkIntensity,
    required this.sessionLocked,
    required this.requireReauth,
    required this.breakdown,
  });

  static const low = RiskState(
    score: 0,
    tier: 'low',
    watermarkIntensity: 'normal',
    sessionLocked: false,
    requireReauth: false,
    breakdown: {},
  );

  factory RiskState.fromRow(Map<String, dynamic> row) {
    return RiskState(
      score: (row['score'] as num?)?.toInt() ?? 0,
      tier: row['tier'] as String? ?? 'low',
      watermarkIntensity: row['watermark_intensity'] as String? ?? 'normal',
      sessionLocked: row['session_locked'] as bool? ?? false,
      requireReauth: row['require_reauth'] as bool? ?? false,
      breakdown: Map<String, dynamic>.from(row['breakdown'] as Map? ?? {}),
    );
  }
}

class RiskEngineService {
  RiskEngineService._();
  static final RiskEngineService instance = RiskEngineService._();

  /// Realtime stream of the given user's own risk state. RLS restricts the
  /// underlying table to that user's row (plus super-admins), but this
  /// method always filters to [userId] explicitly — this is "my risk
  /// state", not an admin console.
  Stream<RiskState> watch(String userId) {
    return SupabaseService.instance.watchMyRiskState(userId).map(
          (row) => row == null ? RiskState.low : RiskState.fromRow(row),
        );
  }

  /// Clears require_reauth/session_locked for the caller after a fresh
  /// sign-in. See acknowledge_reauth() in the migration for why this is
  /// safe to expose without an admin check — it only ever touches the
  /// caller's own row.
  Future<void> acknowledgeReauth() async {
    try {
      await SupabaseService.instance.acknowledgeReauth();
    } catch (e) {
      debugLog('RiskEngineService: acknowledgeReauth failed: $e');
    }
  }
}
