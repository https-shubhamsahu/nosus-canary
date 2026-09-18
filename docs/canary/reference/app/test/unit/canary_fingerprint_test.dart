import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/canary/domain/canary_fingerprint.dart';
import 'package:no_sus/features/canary/presentation/canary_composer_screen.dart'
    show kCanaryDemoNote;

final _zeroWidth = RegExp(
  '[${String.fromCharCode(0x2060)}${String.fromCharCode(0x200B)}${String.fromCharCode(0x200C)}]',
);

String _stripMarkers(String s) => s.replaceAll(_zeroWidth, '');

void main() {
  final plan = buildCanaryPlan(kCanaryDemoNote);
  final codewords = generateCanaryCodewords(
    50,
    plan.bitCount,
    random: Random(42),
  );
  final copies = [
    for (var i = 0; i < codewords.length; i++)
      renderCanaryCopy(plan, codewords[i], copyIndex: i),
  ];

  test('demo note has enough swappable words for 100 readers', () {
    expect(plan.bitCount, greaterThanOrEqualTo(canaryRequiredSlots(100)));
    expect(canaryMaxCopiesFor(plan), 100);
  });

  test('all-zero codeword reproduces the original note exactly', () {
    expect(
      renderCanaryCopy(plan, List<int>.filled(plan.bitCount, 0)),
      kCanaryDemoNote,
    );
  });

  test('every copy is different and carries its own marker', () {
    expect(copies.map(_stripMarkers).toSet().length, copies.length);
    for (var i = 0; i < copies.length; i++) {
      expect(decodeCanaryMarker(copies[i]), i);
    }
  });

  test('exact copy is identified by the invisible marker', () {
    final match = matchCanaryLeak(copies[7], plan, codewords);
    expect(match.kind, CanaryMatchKind.exactMarker);
    expect(match.copyIndex, 7);
  });

  test('marker-stripped copy is identified by its words', () {
    final match = matchCanaryLeak(_stripMarkers(copies[12]), plan, codewords);
    expect(match.kind, CanaryMatchKind.confident);
    expect(match.copyIndex, 12);
  });

  test('OCR-like text (caps, no punctuation, line breaks) still matches', () {
    final ocr = _stripMarkers(copies[30])
        .replaceAll(RegExp(r'[,.!?]'), '')
        .replaceAll(' ', '\n')
        .toUpperCase();
    final match = matchCanaryLeak(ocr, plan, codewords);
    expect(match.kind, CanaryMatchKind.confident);
    expect(match.copyIndex, 30);
  });

  test("sender's original is reported as the original, not a reader", () {
    final match = matchCanaryLeak(kCanaryDemoNote, plan, codewords);
    expect(match.kind, CanaryMatchKind.senderOriginal);
    expect(match.copyIndex, isNull);
  });

  test('unrelated text never names anyone', () {
    final match = matchCanaryLeak(
      'The quick brown fox jumps over the lazy dog.',
      plan,
      codewords,
    );
    expect(match.copyIndex, isNull);
  });

  test('partial excerpts never name the wrong copy', () {
    final rng = Random(7);
    for (var t = 0; t < 200; t++) {
      final i = rng.nextInt(copies.length);
      final clean = _stripMarkers(copies[i]);
      final from = (clean.length * rng.nextDouble() * 0.5).floor();
      final to = (from + clean.length * 0.35).floor().clamp(0, clean.length);
      final match = matchCanaryLeak(clean.substring(from, to), plan, codewords);
      if (match.copyIndex != null) expect(match.copyIndex, i);
    }
  });

  test('too-short notes are rejected for large reader counts', () {
    final short = buildCanaryPlan("Hi, please don't share this. Okay?");
    expect(short.bitCount, lessThan(canaryRequiredSlots(10)));
    expect(
      () => generateCanaryCodewords(10, short.bitCount),
      throwsStateError,
    );
  });

  test('plan survives a JSON round trip', () {
    final restored = CanaryPlan.fromJson(
      Map<String, dynamic>.from(plan.toJson()),
    );
    expect(restored.tokens, plan.tokens);
    expect(restored.bitCount, plan.bitCount);
    expect(
      renderCanaryCopy(restored, codewords[3], copyIndex: 3),
      copies[3],
    );
  });
}
