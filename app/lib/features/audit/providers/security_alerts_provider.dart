import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';

/// Unacknowledged security_alerts visible to the current user under RLS —
/// group admins see alerts for their groups, super-admins see all, everyone
/// sees their own (see 20260710030000_risk_engine.sql). Empty for the vast
/// majority of users, which is why the UI hides itself entirely when empty
/// rather than showing an empty-state card.
final securityAlertsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return SupabaseService.instance.fetchSecurityAlerts();
});
