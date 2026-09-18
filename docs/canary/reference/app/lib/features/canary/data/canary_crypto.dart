import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../../../services/burn_file_crypto.dart' show bytesToHex, hexToBytes;

/// Crypto helpers for NO SUS Canary. Uses exactly the same AES setup as Burn
/// Notes (package:encrypt, AES-256, default mode, random 16-byte IV) so there
/// is no new primitive to review.
class CanaryCrypto {
  const CanaryCrypto._();

  static String randomHex(int byteCount) {
    final random = Random.secure();
    return bytesToHex(
      Uint8List.fromList(List<int>.generate(byteCount, (_) => random.nextInt(256))),
    );
  }

  static String sha256Hex(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  static ({String ciphertextB64, String ivHex}) encrypt(
    String plaintext,
    String keyHex,
  ) {
    final key = enc.Key(hexToBytes(keyHex));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = enc.Encrypter(enc.AES(key)).encrypt(plaintext, iv: iv);
    return (ciphertextB64: encrypted.base64, ivHex: bytesToHex(iv.bytes));
  }

  /// Throws if the key is wrong or the data is damaged.
  static String decrypt(String ciphertextB64, String ivHex, String keyHex) {
    final key = enc.Key(hexToBytes(keyHex));
    final iv = enc.IV(hexToBytes(ivHex));
    return enc.Encrypter(enc.AES(key)).decrypt64(ciphertextB64, iv: iv);
  }

  /// Commitment to one copy: `sha256("<salt>:<index>:<copy text>")`.
  static String copyDigest(String saltHex, int index, String copyText) =>
      sha256Hex('$saltHex:$index:$copyText');

  /// Commitment to every copy, written to Monad: sha256 of the digests
  /// concatenated in copy order, as 0x-prefixed hex.
  static String copiesHash(List<String> copyDigests) =>
      '0x${sha256Hex(copyDigests.join())}';
}
