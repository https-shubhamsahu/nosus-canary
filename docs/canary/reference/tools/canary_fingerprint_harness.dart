import 'dart:math';
import '../app/lib/features/canary/domain/canary_fingerprint.dart';

const demoNote =
    "Hey everyone, please don't share this outside the group. We're launching "
    "the new app on Friday and it's almost ready. The first five people who "
    "sign up get early access, so kindly keep it quiet till the launch. I'll "
    "organize a small call afterwards for anyone who wants a demo. Let's make "
    "sure nobody posts screenshots, okay?";

const longNote =
    "Hi everyone, please don't forward this. We're finalizing the budget and it's nearly done. "
    "The first ten people who reply can join the review, so kindly keep it quiet until Monday. "
    "I'll organize a short call afterwards for anybody who can't read the whole email. "
    "Someone from finance will share the favorite options, okay? Let's make sure nobody posts "
    "screenshots, and maybe we can wrap up by five. There's a lot riding on this, so don't be late.";

final zwChars = RegExp(
  '[${String.fromCharCode(0x2060)}${String.fromCharCode(0x200B)}${String.fromCharCode(0x200C)}]',
);

String stripZw(String s) => s.replaceAll(zwChars, '');

String ocrLike(String s) => stripZw(s)
    .replaceAll(RegExp(r'[,.!?]'), '')
    .replaceAll(' ', '\n')
    .toUpperCase();

String noisy(String s, Random rng, double rate) {
  final chars = stripZw(s).split('');
  for (var i = 0; i < chars.length; i++) {
    if (RegExp('[a-z]').hasMatch(chars[i]) && rng.nextDouble() < rate) {
      chars[i] = String.fromCharCode(97 + rng.nextInt(26));
    }
  }
  return chars.join();
}

String excerpt(String s, double from, double to) {
  final clean = stripZw(s);
  return clean.substring(
    (clean.length * from).floor(),
    (clean.length * to.clamp(0, 1)).floor(),
  );
}

var failures = 0;

void expectKind(String label, CanaryMatch m, Set<CanaryMatchKind> kinds, {int? copy}) {
  final ok = kinds.contains(m.kind) && (copy == null || m.copyIndex == copy);
  print('${ok ? "PASS" : "FAIL"}  $label -> ${m.kind.name} copy=${m.copyIndex} cand=${m.candidates} ${m.agreeing}/${m.known}');
  if (!ok) failures++;
}

bool named(CanaryMatch m) =>
    m.kind == CanaryMatchKind.confident ||
    m.kind == CanaryMatchKind.likely ||
    m.kind == CanaryMatchKind.exactMarker;

void runFor(String title, String note, int copyCount) {
  print('');
  print('==================== $title ($copyCount copies)');
  final plan = buildCanaryPlan(note);
  print('slots=${plan.bitCount} required=${canaryRequiredSlots(copyCount)} maxCopies=${canaryMaxCopiesFor(plan)}');
  for (final s in plan.slots) {
    print('  slot "${s.original}" -> "${s.alternate}"');
  }
  if (plan.bitCount < canaryRequiredSlots(copyCount)) {
    print('REJECTED (as designed): note too short for $copyCount copies');
    return;
  }
  final codes = generateCanaryCodewords(copyCount, plan.bitCount, random: Random(42));
  final copies = [
    for (var i = 0; i < codes.length; i++) renderCanaryCopy(plan, codes[i], copyIndex: i),
  ];
  print('sample copy 1: ${stripZw(copies[0])}');
  print('original == zero render: ${renderCanaryCopy(plan, List.filled(plan.bitCount, 0)) == note}');

  expectKind('exact marker copy 7', matchCanaryLeak(copies[7], plan, codes), {CanaryMatchKind.exactMarker}, copy: 7);
  expectKind('zw stripped copy 7', matchCanaryLeak(stripZw(copies[7]), plan, codes), {CanaryMatchKind.confident}, copy: 7);
  expectKind('ocr formatting copy 12', matchCanaryLeak(ocrLike(copies[12]), plan, codes), {CanaryMatchKind.confident}, copy: 12);
  expectKind('sender original', matchCanaryLeak(note, plan, codes), {CanaryMatchKind.senderOriginal});
  expectKind('unrelated text', matchCanaryLeak('the quick brown fox jumps over the lazy dog', plan, codes), {CanaryMatchKind.notEnough, CanaryMatchKind.noMatch});

  final rng = Random(7);
  var okStrip = 0, okOcr = 0, okNoise = 0, wrongNoise = 0;
  const trials = 300;
  for (var t = 0; t < trials; t++) {
    final i = rng.nextInt(codes.length);
    final a = matchCanaryLeak(stripZw(copies[i]), plan, codes);
    if (named(a) && a.copyIndex == i) okStrip++;
    final b = matchCanaryLeak(ocrLike(copies[i]), plan, codes);
    if (named(b) && b.copyIndex == i) okOcr++;
    final c = matchCanaryLeak(noisy(copies[i], rng, 0.02), plan, codes);
    if (named(c) && c.copyIndex == i) okNoise++;
    if (named(c) && c.copyIndex != i) wrongNoise++;
  }
  print('sweep: stripped $okStrip/$trials, ocr $okOcr/$trials, 2% noise right $okNoise/$trials, WRONG $wrongNoise/$trials');
  if (wrongNoise > 0) failures++;

  var exRight = 0, exWrong = 0, colluder = 0, innocent = 0;
  for (var t = 0; t < 600; t++) {
    final i = rng.nextInt(codes.length);
    final from = rng.nextDouble() * 0.5;
    final to = from + 0.3 + rng.nextDouble() * 0.2;
    final m = matchCanaryLeak(excerpt(copies[i], from, to), plan, codes);
    if (named(m)) {
      if (m.copyIndex == i) {
        exRight++;
      } else {
        exWrong++;
      }
    }
    final j = (i + 1 + rng.nextInt(codes.length - 1)) % codes.length;
    final mix = [for (var k = 0; k < plan.bitCount; k++) rng.nextBool() ? codes[i][k] : codes[j][k]];
    final bm = matchCanaryLeak(renderCanaryCopy(plan, mix), plan, codes);
    if (named(bm)) {
      if (bm.copyIndex == i || bm.copyIndex == j) {
        colluder++;
      } else {
        innocent++;
      }
    }
  }
  print('excerpts: named right $exRight/600, WRONG $exWrong/600');
  print('two-copy blends: named a colluder $colluder/600, named an INNOCENT $innocent/600');
  if (exWrong > 0) failures++;

  final distinct = copies.map(stripZw).toSet().length;
  if (distinct != copies.length) {
    print('FAIL distinct copies $distinct/${copies.length}');
    failures++;
  }
  for (var i = 0; i < codes.length; i++) {
    if (decodeCanaryMarker(copies[i]) != i) {
      print('FAIL marker $i');
      failures++;
    }
  }
}

void main() {
  runFor('DEMO NOTE', demoNote, 20);
  runFor('LONG NOTE', longNote, 20);
  runFor('LONG NOTE', longNote, 50);
  runFor('LONG NOTE', longNote, 100);
  print('');
  print('FAILURES: $failures');
}
