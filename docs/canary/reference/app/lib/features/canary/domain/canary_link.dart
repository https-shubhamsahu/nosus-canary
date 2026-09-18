import 'dart:convert';

import 'package:crypto/crypto.dart';

/// What a reader link carries. The key lives in the URL fragment, which
/// browsers never send to a server.
class CanaryLinkToken {
  const CanaryLinkToken({required this.noteId, required this.keyHex});

  /// Lowercase UUID v4, e.g. 1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed.
  final String noteId;

  /// 64 lowercase hex characters (AES-256 key).
  final String keyHex;
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final RegExp _keyPattern = RegExp(r'^[0-9a-f]{64}$');

/// Reader link: `<origin><basePath>/#/canary/<noteId>?k=<keyHex>`.
/// Same shape as Burn links (query inside the fragment).
String buildCanaryReaderLink({
  required String origin,
  required String basePath,
  required String noteId,
  required String keyHex,
}) => '$origin$basePath/#/canary/$noteId?k=$keyHex';

/// Parses a full URL (including its fragment). Returns null for anything that
/// is not exactly a Canary reader link.
CanaryLinkToken? parseCanaryReaderLink(String fullUrl) {
  final hashIndex = fullUrl.indexOf('#');
  if (hashIndex == -1) return null;
  final fragment = fullUrl.substring(hashIndex + 1);
  final queryIndex = fragment.indexOf('?');
  if (queryIndex == -1) return null;

  final path = fragment.substring(0, queryIndex).toLowerCase();
  final params = Uri.splitQueryString(fragment.substring(queryIndex + 1));
  final match = RegExp(r'^/?canary/([0-9a-f\-]{36})$').firstMatch(path);
  final key = params['k']?.toLowerCase();
  if (match == null || key == null) return null;

  final noteId = match.group(1)!;
  if (!_uuidPattern.hasMatch(noteId) || !_keyPattern.hasMatch(key)) {
    return null;
  }
  return CanaryLinkToken(noteId: noteId, keyHex: key);
}

/// The bytes32 note id used on Monad: sha256("nosus-canary:" + noteId).
/// The edge function computes the same value; keep them identical.
String canaryChainNoteId(String noteId) =>
    '0x${sha256.convert(utf8.encode('nosus-canary:$noteId'))}';

/// Public block explorer page for a Monad testnet transaction.
String canaryExplorerTxUrl(String txHash) =>
    'https://testnet.monadscan.com/tx/$txHash';
