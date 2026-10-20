import 'dart:convert';

import 'package:nosus_receipts/nosus_receipts.dart';
import 'package:test/test.dart';

import 'vectors.dart';

SealReceipt _seal(Map<String, dynamic> i) => SealReceipt(
  note: i['note'] as String,
  copies: i['copies'] as int,
  hash: i['hash'] as String,
  exp: i['exp'] as int,
);

OpenReceipt _open(Map<String, dynamic> i) => OpenReceipt(
  note: i['note'] as String,
  copy: i['copy'] as int,
  tag: i['tag'] as String,
);

void main() {
  test('seal memos encode to the exact vector bytes and parse back', () {
    for (final v in section('sealMemo')) {
      final input = v['input'] as Map<String, dynamic>;
      expect(_seal(input).encode(), v['memo'], reason: v['name'] as String);
      final parsed = ReceiptMemo.parse(v['memo'] as String) as SealReceipt;
      expect(
        [parsed.type, parsed.note, parsed.copies, parsed.hash, parsed.exp],
        ['seal', input['note'], input['copies'], input['hash'], input['exp']],
      );
    }
  });

  test('open memos encode to the exact vector bytes and parse back', () {
    for (final v in section('openMemo')) {
      final input = v['input'] as Map<String, dynamic>;
      expect(_open(input).encode(), v['memo'], reason: v['name'] as String);
      final parsed = ReceiptMemo.parse(v['memo'] as String) as OpenReceipt;
      expect(
        [parsed.type, parsed.note, parsed.copy, parsed.tag],
        ['open', input['note'], input['copy'], input['tag']],
      );
    }
  });

  test('the largest memo today is 219 bytes', () {
    final sizes = [
      ...section('sealMemo'),
      ...section('openMemo'),
    ].map((v) => utf8.encode(v['memo'] as String).length);
    expect(sizes.reduce((a, b) => a > b ? a : b), 219);
    expect(maxMemoBytes, vectors['maxMemoBytes']);
  });

  test('constructors reject bad fields with the shared messages', () {
    for (final v in section('encodeErrors')) {
      final input = v['input'] as Map<String, dynamic>;
      expect(
        () => v['kind'] == 'seal' ? _seal(input) : _open(input),
        throwsA(
          isA<ReceiptFormatException>().having(
            (e) => e.message,
            'message',
            v['error'],
          ),
        ),
        reason: v['name'] as String,
      );
    }
  });

  test('parse rejects every invalid vector with the shared message', () {
    for (final v in section('invalidMemos')) {
      expect(
        () => ReceiptMemo.parse(v['memo'] as String),
        throwsA(
          isA<ReceiptFormatException>().having(
            (e) => e.message,
            'message',
            v['error'],
          ),
        ),
        reason: v['name'] as String,
      );
    }
  });

  test('memo program ids', () {
    expect(memoProgramIds, contains(defaultMemoProgram));
    expect(
      memoProgramIds,
      contains((vectors['rawMemoInstruction'] as Map)['programId']),
    );
  });
}
