import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/supabase_credentials.dart';
import '../domain/canary_models.dart';

/// Thrown for every failed call. [message] is safe to show to the person.
class CanaryApiException implements Exception {
  const CanaryApiException(this.message, {this.retryable = false});
  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

/// Talks to the single `canary` Supabase Edge Function. Same calling pattern
/// as RedemptionCodeClient: plain HTTPS, publishable key, no session.
class CanaryApi {
  CanaryApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri endpoint = Uri.parse(
    '${SupabaseCredentials.url}/functions/v1/canary',
  );

  Future<Map<String, dynamic>> _post(
    Map<String, Object?> body, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseCredentials.anonKey,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } catch (_) {
      throw const CanaryApiException(
        'Could not reach NO SUS. Check your connection and try again.',
        retryable: true,
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw CanaryApiException(
        'Unexpected reply from NO SUS (${response.statusCode}).',
        retryable: response.statusCode >= 500,
      );
    }
    if (response.statusCode != 200) {
      throw CanaryApiException(
        decoded['error'] as String? ??
            'Something went wrong (${response.statusCode}).',
        retryable: decoded['retry'] == true || response.statusCode >= 500,
      );
    }
    return decoded;
  }

  /// Uploads every encrypted copy and seals the note on Monad.
  Future<({String sealTxHash, DateTime expiresAt})> create({
    required String noteId,
    required String ownerHash,
    required int copyCount,
    required String copiesHash,
    required int expiresInHours,
    required List<({int index, String ciphertext, String iv})> copies,
  }) async {
    final result = await _post({
      'action': 'create',
      'note_id': noteId,
      'owner_hash': ownerHash,
      'copy_count': copyCount,
      'copies_hash': copiesHash,
      'expires_in_hours': expiresInHours,
      'copies': [
        for (final c in copies)
          {'index': c.index, 'ciphertext': c.ciphertext, 'iv': c.iv},
      ],
    }, timeout: const Duration(seconds: 60));
    return (
      sealTxHash: result['seal_tx_hash'] as String,
      expiresAt: DateTime.parse(result['expires_at'] as String),
    );
  }

  /// Gives this device its own copy (the same one again on retries).
  Future<
    ({
      int copyIndex,
      int copyCount,
      String ciphertext,
      String iv,
      String? openTxHash,
      DateTime openedAt,
    })
  >
  open({
    required String noteId,
    required String deviceId,
    required String readerName,
  }) async {
    final r = await _post({
      'action': 'open',
      'note_id': noteId,
      'device_id': deviceId,
      'reader_name': readerName,
    });
    return (
      copyIndex: r['copy_index'] as int,
      copyCount: r['copy_count'] as int,
      ciphertext: r['ciphertext'] as String,
      iv: r['iv'] as String,
      openTxHash: r['open_tx_hash'] as String?,
      openedAt: DateTime.parse(r['opened_at'] as String),
    );
  }

  /// Owner-only: who opened which copy. Proven with the owner secret.
  Future<CanaryNoteStatus> status({
    required String noteId,
    required String ownerSecret,
  }) async {
    final r = await _post({
      'action': 'status',
      'note_id': noteId,
      'owner_secret': ownerSecret,
    });
    return CanaryNoteStatus(
      copyCount: r['copy_count'] as int,
      sealTxHash: r['seal_tx_hash'] as String?,
      expiresAt: DateTime.parse(r['expires_at'] as String),
      copies: [
        for (final c in r['copies'] as List)
          CanaryCopyStatus(
            copyIndex: (c as Map)['copy_index'] as int,
            readerName: c['reader_name'] as String,
            openedAt: DateTime.parse(c['opened_at'] as String),
            openTxHash: c['open_tx_hash'] as String?,
          ),
      ],
    );
  }
}
