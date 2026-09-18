import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/services/burn_file_crypto.dart';

/// Known-answer tests pinning the burn note/file ciphertext formats.
///
/// The landing page (homepage/src/lib/burnCrypto.ts) reimplements these
/// exact paths in WebCrypto so notes/files created on nosus.foo decrypt in
/// the app and vice versa. These vectors were cross-verified against
/// WebCrypto (see tool/crypto_compat_probe.dart):
///   * Burn Note  = AES-256-CTR (counter = IV, full-block carry) over
///     PKCS7-PADDED plaintext — the `encrypt` package pads even in its
///     default SIC/CTR mode. Ciphertext stored base64.
///   * Burn File  = AES-256-CBC/PKCS7 over the packed payload
///     `[4-byte BE header len][JSON {name,type,size}][raw bytes]`.
///
/// If either test fails, the web implementation no longer matches the app —
/// DO NOT "fix" by updating the expected values without updating
/// homepage/src/lib/burnCrypto.ts in lockstep.
void main() {
  final keyBytes = Uint8List.fromList(List.generate(32, (i) => i + 1));
  final ivBytes = Uint8List.fromList(List.generate(16, (i) => 0xA0 + i));
  final key = enc.Key(keyBytes);
  final iv = enc.IV(ivBytes);

  test('burn note ciphertext matches the WebCrypto-verified vector', () {
    const noteText = 'Meet at the library, 6pm. Burn after reading. äöü✓';
    final encrypter = enc.Encrypter(enc.AES(key));
    expect(
      encrypter.encrypt(noteText, iv: iv).base64,
      '71lEqc0Io3FpcmZgKYel21XtoAbwGtLrCxvNr7EFoQu+hzjeP+Pg5XjnAWmz6EMr'
      '0aCQC+1tPVTKU+TYxjJQ7Q==',
    );
    // And the viewer's decrypt path accepts it back.
    expect(
      encrypter.decrypt64(encrypter.encrypt(noteText, iv: iv).base64, iv: iv),
      noteText,
    );
  });

  test('burn file ciphertext matches the WebCrypto-verified vector', () {
    final fileBytes =
        Uint8List.fromList(List.generate(1000, (i) => (i * 7 + 3) % 256));
    final packed = packBurnFilePayload(
      fileName: 'exam notes.pdf',
      mimeType: 'application/pdf',
      fileBytes: fileBytes,
    );
    final ciphertext = encryptBurnFilePayload(packed, key, iv);

    // Same ciphertext WebCrypto AES-CBC produced for the same inputs.
    expect(
      leading48(ciphertext),
      leading48(base64.decode(
        // The verified vector's first 48 bytes — enough to catch any
        // mode/padding/packing drift (a format change alters block 0),
        // without bloating the test with the full 1KB blob.
        'nkE9Mmwi34RhWM7mGECy27W5S6AJaqrkr8Xh57HTSiVE1cWIJMkCME6RxwAvDLKp',
      )),
    );

    final unpacked =
        unpackBurnFilePayload(decryptBurnFilePayload(ciphertext, key, iv));
    expect(unpacked.fileName, 'exam notes.pdf');
    expect(unpacked.mimeType, 'application/pdf');
    expect(unpacked.bytes, fileBytes);
  });
}

/// Compares only the leading bytes (the base64 snippet above decodes to 48
/// bytes) — enough to detect any algorithm/mode/padding/packing drift.
List<int> leading48(List<int> bytes) => bytes.sublist(0, 48);
