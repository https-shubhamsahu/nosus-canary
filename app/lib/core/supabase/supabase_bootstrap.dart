import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_credentials.dart';
import '../auth/session_recovery.dart';

/// Owns the one-time Supabase SDK initialization for the application.
final class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static bool get isConfigured =>
      SupabaseCredentials.url.isNotEmpty &&
      SupabaseCredentials.anonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) {
      throw StateError('Supabase credentials are not configured.');
    }

    await Supabase.initialize(
      url: SupabaseCredentials.url,
      publishableKey: SupabaseCredentials.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        detectSessionInUri: true,
      ),
    );
    // A persisted session is usable immediately. If its access token is stale,
    // refresh without making the first Flutter frame wait for the network.
    unawaited(SessionRecovery.recoverIfNeeded(Supabase.instance.client.auth));
  }
}
