import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../config/supabase_credentials.dart';

/// Calls the "create-redemption-code" / "redeem-code" Edge Functions —
/// matches [BurnFileClient]'s pattern exactly (no Supabase client, no
/// session, anonymous on both ends). See
/// supabase/migrations/20260713000000_burn_redemption_codes.sql for why
/// this path deliberately differs from the link-based zero-knowledge
/// guarantee: the server briefly holds the key/IV. New two-digit codes are
/// paired with an unguessable link token, so the short value is never the
/// authorization boundary.
class RedemptionCodeClient {
  RedemptionCodeClient._();
  static final RedemptionCodeClient instance = RedemptionCodeClient._();

  static final Uri _createEndpoint = Uri.parse(
    '${SupabaseCredentials.url}/functions/v1/create-redemption-code',
  );
  static final Uri _redeemEndpoint = Uri.parse(
    '${SupabaseCredentials.url}/functions/v1/redeem-code',
  );

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'apikey': SupabaseCredentials.anonKey,
  };

  /// Sender side: mints a two-digit pairing code and an unguessable redeem
  /// token. Both are required for the alternate retrieval path.
  /// [targetKind] is `'note'` or `'file'`.
  Future<({String code, String redeemToken, DateTime expiresAt})> createCode({
    required String targetKind,
    required String targetId,
    required String keyHex,
    required String ivHex,
  }) async {
    final res = await http.post(
      _createEndpoint,
      headers: _headers,
      body: jsonEncode({
        'target_kind': targetKind,
        'target_id': targetId,
        'key_hex': keyHex,
        'iv_hex': ivHex,
      }),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(
        decoded['error'] as String? ?? 'Could not create a code.',
      );
    }
    return (
      code: decoded['code'] as String,
      redeemToken: decoded['redeem_token'] as String,
      expiresAt: DateTime.parse(decoded['expires_at'] as String),
    );
  }

  /// Recipient side: atomically claims a code. New two-digit pairing codes
  /// require [redeemToken] from the secure link; the optional form only keeps
  /// short-lived legacy eight-character codes working during rollout.
  Future<({String targetKind, String targetId, String keyHex, String ivHex})>
  redeem(String code, {String? redeemToken}) async {
    final payload = <String, String>{'code': code};
    if (redeemToken != null) payload['redeem_token'] = redeemToken;
    final res = await http.post(
      _redeemEndpoint,
      headers: _headers,
      body: jsonEncode(payload),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(
        decoded['error'] as String? ?? 'That code could not be redeemed.',
      );
    }
    return (
      targetKind: decoded['target_kind'] as String,
      targetId: decoded['target_id'] as String,
      keyHex: decoded['key_hex'] as String,
      ivHex: decoded['iv_hex'] as String,
    );
  }
}
