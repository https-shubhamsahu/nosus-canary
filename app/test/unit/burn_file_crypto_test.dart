import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/services/burn_file_crypto.dart';

void main() {
  group('pack/unpackBurnFilePayload', () {
    test('round-trips name, mime type, and bytes', () {
      final original = Uint8List.fromList(List.generate(256, (i) => i % 256));
      final packed = packBurnFilePayload(
        fileName: 'report.pdf',
        mimeType: 'application/pdf',
        fileBytes: original,
      );
      final unpacked = unpackBurnFilePayload(packed);

      expect(unpacked.fileName, 'report.pdf');
      expect(unpacked.mimeType, 'application/pdf');
      expect(unpacked.bytes, original);
    });

    test('round-trips a filename with unicode and special characters', () {
      final original = Uint8List.fromList([1, 2, 3, 4, 5]);
      final packed = packBurnFilePayload(
        fileName: '成绩单 — final (v2)  😀.pdf',
        mimeType: 'application/pdf',
        fileBytes: original,
      );
      final unpacked = unpackBurnFilePayload(packed);

      expect(unpacked.fileName, '成绩单 — final (v2)  😀.pdf');
      expect(unpacked.bytes, original);
    });

    test('round-trips a zero-byte file', () {
      final original = Uint8List(0);
      final packed = packBurnFilePayload(
        fileName: 'empty.txt',
        mimeType: 'text/plain',
        fileBytes: original,
      );
      final unpacked = unpackBurnFilePayload(packed);

      expect(unpacked.fileName, 'empty.txt');
      expect(unpacked.bytes, isEmpty);
    });
  });

  group('encrypt/decryptBurnFilePayload', () {
    test('round-trips through AES-256-CBC with a fresh key/IV', () {
      final keyMaterial = generateBurnFileKeyMaterial();
      final packed = packBurnFilePayload(
        fileName: 'secret.bin',
        mimeType: 'application/octet-stream',
        fileBytes: Uint8List.fromList(List.generate(1000, (i) => (i * 7) % 256)),
      );

      final ciphertext = encryptBurnFilePayload(packed, keyMaterial.key, keyMaterial.iv);
      // Ciphertext must not equal plaintext, and must not trivially reveal size
      // relationships that break confidentiality assumptions.
      expect(ciphertext, isNot(equals(packed)));

      final decrypted = decryptBurnFilePayload(ciphertext, keyMaterial.key, keyMaterial.iv);
      expect(decrypted, packed);

      final unpacked = unpackBurnFilePayload(decrypted);
      expect(unpacked.fileName, 'secret.bin');
    });

    test('decrypting with the wrong key never recovers the original bytes', () {
      // Under CBC+PKCS7, a wrong key almost always fails PKCS7 padding
      // validation on the last block and throws, rather than silently
      // returning garbage — that's the desirable property (tampering/wrong
      // key fails loudly). Either way, the original bytes must never come
      // back out.
      final keyMaterial = generateBurnFileKeyMaterial();
      final wrongKeyMaterial = generateBurnFileKeyMaterial();
      final packed = packBurnFilePayload(
        fileName: 'a.txt',
        mimeType: 'text/plain',
        fileBytes: Uint8List.fromList([1, 2, 3]),
      );
      final ciphertext = encryptBurnFilePayload(packed, keyMaterial.key, keyMaterial.iv);

      Uint8List? decrypted;
      try {
        decrypted = decryptBurnFilePayload(ciphertext, wrongKeyMaterial.key, keyMaterial.iv);
      } catch (_) {
        // Padding-validation failure is an acceptable, expected outcome.
      }
      if (decrypted != null) {
        expect(decrypted, isNot(equals(packed)));
      }
    });
  });

  group('hex helpers', () {
    test('bytesToHex/hexToBytes round-trip', () {
      final bytes = Uint8List.fromList([0, 1, 15, 16, 255]);
      final hex = bytesToHex(bytes);
      expect(hex, '00010f10ff');
      expect(hexToBytes(hex), bytes);
    });
  });
}
