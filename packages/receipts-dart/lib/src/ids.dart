// The sha256-based ids and hashes a receipt carries. Inputs are hashed as
// UTF-8 text; outputs are lowercase hex. Same formulas as the Canary app and
// the edge function, so anyone can recompute them.

import 'dart:convert';

import 'package:crypto/crypto.dart';

String _sha256Hex(String text) => sha256.convert(utf8.encode(text)).toString();

/// The memo `note`: "0x" + sha256("nosus-canary:" + noteId). noteId is a
/// lowercase UUID.
String chainNoteId(String noteId) => '0x${_sha256Hex('nosus-canary:$noteId')}';

/// sha256("device:" + deviceId), no 0x. Only ever stored or hashed again,
/// never on chain.
String deviceHash(String deviceId) => _sha256Hex('device:$deviceId');

/// The open memo `tag`:
/// `"0x" + sha256("<tagSalt>:<noteId>:<copyIndex>:<deviceHash>")`.
/// tagSalt is the relayer's secret, so only the relayer can recompute it.
String readerTag({
  required String tagSalt,
  required String noteId,
  required int copyIndex,
  required String deviceHash,
}) => '0x${_sha256Hex('$tagSalt:$noteId:$copyIndex:$deviceHash')}';

/// Commitment to one copy: `sha256("<saltHex>:<index>:<copyText>")`, no 0x.
String copyDigest(String saltHex, int index, String copyText) =>
    _sha256Hex('$saltHex:$index:$copyText');

/// The seal memo `hash`: "0x" + sha256 of the copy digests joined in copy
/// order.
String copiesHash(List<String> copyDigests) =>
    '0x${_sha256Hex(copyDigests.join())}';
