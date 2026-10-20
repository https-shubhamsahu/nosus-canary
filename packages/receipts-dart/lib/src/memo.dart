// NO SUS Canary receipt memo, format v1 (spec: docs/RECEIPTS_SPEC.md).
//
// One SPL Memo per seal and per open. The memo is compact JSON with a fixed
// key order, so the same receipt is always the same bytes:
//   {"p":"nosus-canary","v":1,"t":"seal","note":"0x…","copies":N,"hash":"0x…","exp":E}
//   {"p":"nosus-canary","v":1,"t":"open","note":"0x…","copy":N,"tag":"0x…"}

import 'dart:convert';

const receiptProtocol = 'nosus-canary';
const receiptVersion = 1;

/// Longest memo a single-signer transaction can carry.
const maxMemoBytes = 566;

/// SPL Memo v3 (Solana Explorer shows the memo text).
const defaultMemoProgram = 'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr';

/// Memo programs a receipt may be written with: SPL Memo v1, v3 and p-memo.
const memoProgramIds = [
  'Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo',
  defaultMemoProgram,
  'Memo4c2pN8afCj432Lb7RMVKi9PbQnnW7ewFFaV3oAH',
];

/// A memo or memo field that is not exactly format v1.
class ReceiptFormatException extends FormatException {
  const ReceiptFormatException(super.message);

  @override
  String toString() => 'ReceiptFormatException: $message';
}

final _bytes32 = RegExp(r'^0x[0-9a-f]{64}$');
const _maxSafeInteger = 9007199254740991;
const _sealKeys = 'p,v,t,note,copies,hash,exp';
const _openKeys = 'p,v,t,note,copy,tag';

String _checkBytes32(String name, Object? value) {
  if (value is String && _bytes32.hasMatch(value)) return value;
  throw ReceiptFormatException('memo $name must be 0x + 64 hex chars');
}

// Safe integers only (2^53 - 1, as in JavaScript), so every encoded memo
// parses back to the same bytes in both packages. 3.0 passes here and is
// rejected later as not canonical, exactly like the TypeScript parser.
int _checkUint(String name, Object? value) {
  if (value is num &&
      value >= 0 &&
      value <= _maxSafeInteger &&
      value == value.truncate()) {
    return value.toInt();
  }
  throw ReceiptFormatException('memo $name must be a non-negative integer');
}

/// One receipt: a [SealReceipt] or an [OpenReceipt].
sealed class ReceiptMemo {
  const ReceiptMemo();

  /// Strict parse: accepts only the exact bytes [encode] would write. Throws
  /// [ReceiptFormatException] otherwise.
  factory ReceiptMemo.parse(String memo) {
    if (utf8.encode(memo).length > maxMemoBytes) {
      throw const ReceiptFormatException(
        'memo is longer than $maxMemoBytes bytes',
      );
    }
    final Object? m;
    try {
      m = jsonDecode(memo);
    } on FormatException {
      throw const ReceiptFormatException('memo is not JSON');
    }
    if (m is! Map<String, dynamic>) {
      throw const ReceiptFormatException('memo is not a JSON object');
    }
    if (m['p'] != receiptProtocol) {
      throw const ReceiptFormatException('memo p must be "$receiptProtocol"');
    }
    if (m['v'] != receiptVersion) {
      throw const ReceiptFormatException('memo v must be $receiptVersion');
    }
    final t = m['t'];
    if (t != 'seal' && t != 'open') {
      throw const ReceiptFormatException('memo t must be "seal" or "open"');
    }

    final keys = t == 'seal' ? _sealKeys : _openKeys;
    if (m.keys.join(',') != keys) {
      throw ReceiptFormatException('memo keys must be $keys in this order');
    }

    final ReceiptMemo receipt = t == 'seal'
        ? SealReceipt(
            note: _checkBytes32('note', m['note']),
            copies: _checkUint('copies', m['copies']),
            hash: _checkBytes32('hash', m['hash']),
            exp: _checkUint('exp', m['exp']),
          )
        : OpenReceipt(
            note: _checkBytes32('note', m['note']),
            copy: _checkUint('copy', m['copy']),
            tag: _checkBytes32('tag', m['tag']),
          );
    // Catches whitespace, 3.0 / 3e0, duplicate keys and anything else that
    // jsonDecode forgives.
    if (receipt.encode() != memo) {
      throw const ReceiptFormatException('memo is not in canonical form');
    }
    return receipt;
  }

  /// 'seal' or 'open', the memo's `t`.
  String get type;

  /// The memo `note`: [chainNoteId] of the note.
  String get note;

  /// The exact memo text written on chain.
  String encode();
}

/// A sealed note: [copies] marked copies committed to by [hash].
final class SealReceipt extends ReceiptMemo {
  /// Throws [ReceiptFormatException] on a bad field.
  SealReceipt({
    required this.note,
    required this.copies,
    required this.hash,
    required this.exp,
  }) {
    _checkBytes32('note', note);
    _checkUint('copies', copies);
    _checkBytes32('hash', hash);
    _checkUint('exp', exp);
  }

  @override
  final String note;
  final int copies;

  /// [copiesHash] of the copy digests.
  final String hash;

  /// Unix seconds; 0 when the note never expires.
  final int exp;

  @override
  String get type => 'seal';

  @override
  String encode() => jsonEncode({
    'p': receiptProtocol,
    'v': receiptVersion,
    't': 'seal',
    'note': note,
    'copies': copies,
    'hash': hash,
    'exp': exp,
  });
}

/// One opened copy: copy number [copy], reader [tag].
final class OpenReceipt extends ReceiptMemo {
  /// Throws [ReceiptFormatException] on a bad field.
  OpenReceipt({required this.note, required this.copy, required this.tag}) {
    _checkBytes32('note', note);
    _checkUint('copy', copy);
    _checkBytes32('tag', tag);
  }

  @override
  final String note;
  final int copy;

  /// [readerTag] for the device that opened the copy.
  final String tag;

  @override
  String get type => 'open';

  @override
  String encode() => jsonEncode({
    'p': receiptProtocol,
    'v': receiptVersion,
    't': 'open',
    'note': note,
    'copy': copy,
    'tag': tag,
  });
}
