import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

/// Zero-knowledge packing/encryption for Burn Files.
///
/// Unlike burn_notes (text ciphertext stored inline in a DB column, so it
/// only ever needs base64 for the TEXT column type), a Burn File's ciphertext
/// goes straight to Storage as binary — no base64, avoiding ~33% bloat.
///
/// The server never learns the original filename, mime type, or size
/// either: a length-prefixed JSON header is packed in front of the raw file
/// bytes, and the WHOLE packed buffer is encrypted as one blob. The
/// filename deliberately never appears in the share URL either (that would
/// leak via browser history) — it only exists inside the encrypted payload,
/// recovered by [unpackBurnFilePayload] after decryption.
class BurnFilePayload {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const BurnFilePayload({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}

/// `[4-byte big-endian header length][JSON header {name,type,size}][raw file bytes]`.
/// The 4-byte length prefix (rather than a delimiter character) is required
/// because a delimiter could collide with arbitrary binary file content.
Uint8List packBurnFilePayload({
  required String fileName,
  required String mimeType,
  required Uint8List fileBytes,
}) {
  final headerBytes = utf8.encode(jsonEncode({
    'name': fileName,
    'type': mimeType,
    'size': fileBytes.length,
  }));
  final prefix = ByteData(4)..setUint32(0, headerBytes.length, Endian.big);

  return (BytesBuilder(copy: false)
        ..add(prefix.buffer.asUint8List())
        ..add(headerBytes)
        ..add(fileBytes))
      .toBytes();
}

/// Reverses [packBurnFilePayload] after decryption.
BurnFilePayload unpackBurnFilePayload(Uint8List packed) {
  final headerLen = ByteData.sublistView(packed, 0, 4).getUint32(0, Endian.big);
  final header = jsonDecode(utf8.decode(packed.sublist(4, 4 + headerLen)))
      as Map<String, dynamic>;
  return BurnFilePayload(
    fileName: header['name'] as String,
    mimeType: header['type'] as String,
    bytes: packed.sublist(4 + headerLen),
  );
}

/// Generates a fresh random 256-bit key + 128-bit IV, matching burn_notes'
/// CSPRNG approach (`fromSecureRandom`) — but explicit about AES-CBC rather
/// than relying on the `encrypt` package's default mode (SIC/CTR), since a
/// binary blob without burn_notes' string-oriented helpers should not rely
/// on an implicit default.
({enc.Key key, enc.IV iv}) generateBurnFileKeyMaterial() {
  return (key: enc.Key.fromSecureRandom(32), iv: enc.IV.fromSecureRandom(16));
}

Uint8List encryptBurnFilePayload(Uint8List packed, enc.Key key, enc.IV iv) {
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  return encrypter.encryptBytes(packed, iv: iv).bytes;
}

Uint8List decryptBurnFilePayload(Uint8List ciphertext, enc.Key key, enc.IV iv) {
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  return Uint8List.fromList(
    encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: iv),
  );
}

/// Hex helpers matching burn_notes' URL-fragment key/IV encoding exactly
/// (`_bytesToHex`/`_hexToBytes` in burn_note_creator_screen.dart /
/// burn_note_viewer_screen.dart) so both features' links look consistent.
String bytesToHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List hexToBytes(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return bytes;
}
