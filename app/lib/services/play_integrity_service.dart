import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../config/app_integrity_config.dart';
import '../core/utils/debug_logger.dart';
import 'supabase_service.dart';

/// Requests a Play Integrity standard token from the native layer
/// (android/app/.../security/PlayIntegrityManager.kt) and hands it to
/// supabase/functions/verify-play-integrity for server-side verification.
///
/// See [AppIntegrityConfig] for why this is a no-op until explicitly
/// configured and enabled — a Google-signed attestation is a much stronger
/// signal than the client-side heuristics in [DeviceIntegrityService], but
/// only once real setup (Cloud project linkage, real device testing) backs
/// it. Calling this before that setup is complete just returns null.
class PlayIntegrityService {
  PlayIntegrityService._();
  static final PlayIntegrityService instance = PlayIntegrityService._();

  static const _channel = MethodChannel('co.nosus.app/play_integrity');

  /// Requests a token bound to a fresh random nonce and forwards it for
  /// server-side verification. Returns the verdict from
  /// verify-play-integrity, or null if integrity checks aren't
  /// configured/enabled or the request failed for any reason — this is a
  /// best-effort signal, never something that should block the user.
  Future<Map<String, dynamic>?> requestAndVerify() async {
    if (!AppIntegrityConfig.enabled) return null;

    try {
      // Bound into the attestation itself, so a captured token can't be
      // replayed against a later verification call. Doesn't need to be
      // cryptographically derived — just unique and unpredictable per call.
      final nonce = const Uuid().v4().replaceAll('-', '');

      final token = await _channel.invokeMethod<String>('requestToken', {'nonce': nonce});
      if (token == null) return null;

      return await SupabaseService.instance.verifyPlayIntegrityToken(
        token: token,
        nonce: nonce,
      );
    } catch (e) {
      debugLog('NO SUS: Play Integrity check failed (non-fatal): $e');
      return null;
    }
  }
}
