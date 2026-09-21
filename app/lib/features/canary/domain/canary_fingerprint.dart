// NO SUS Canary — fingerprint engine.
//
// Pure Dart (no Flutter imports) so it runs in unit tests and on every
// platform. It turns one note into many copies that differ only in small,
// meaning-preserving word choices ("slots"), and later works out which copy a
// leaked text came from.
//
// Vocabulary used everywhere in this feature:
// * slot      — one word in the original note that has a safe alternate.
// * codeword  — one 0/1 choice per slot. 0 keeps the original word, 1 uses the
//               alternate. Every copy gets a different codeword.
// * copy      — the note rendered with one codeword (+ an invisible marker).
//
// The all-zero codeword is the sender's original text and is never given to a
// reader, so a leak of the sender's own original is reported as such.

import 'dart:math';

/// Single-word key (lowercase, straight apostrophe) -> alternate wording.
/// Only pairs that stay correct in (almost) every sentence are listed.
/// Do not add pairs whose meaning or grammar changes with context
/// (e.g. soon/shortly, help/assist, start/begin, happy/glad).
const Map<String, String> kCanaryAlternates = {
  // Contractions -> expanded forms.
  "don't": 'do not',
  "doesn't": 'does not',
  "didn't": 'did not',
  "can't": 'cannot',
  'cannot': "can't",
  "won't": 'will not',
  "isn't": 'is not',
  "aren't": 'are not',
  "wasn't": 'was not',
  "weren't": 'were not',
  "haven't": 'have not',
  "hasn't": 'has not',
  "hadn't": 'had not',
  "shouldn't": 'should not',
  "wouldn't": 'would not',
  "couldn't": 'could not',
  "it's": 'it is',
  "that's": 'that is',
  "there's": 'there is',
  "what's": 'what is',
  "here's": 'here is',
  "i'm": 'i am',
  "you're": 'you are',
  "we're": 'we are',
  "they're": 'they are',
  "i'll": 'i will',
  "we'll": 'we will',
  "you'll": 'you will',
  "they'll": 'they will',
  "i've": 'i have',
  "we've": 'we have',
  "you've": 'you have',
  "they've": 'they have',
  "let's": 'let us',
  // Number words -> digits and back ("one" is excluded on purpose: "no one").
  'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6',
  'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
  '2': 'two', '3': 'three', '4': 'four', '5': 'five', '6': 'six',
  '7': 'seven', '8': 'eight', '9': 'nine', '10': 'ten',
  // Everyday synonyms that are safe in any position.
  'okay': 'ok',
  'ok': 'okay',
  'hi': 'hello',
  'hello': 'hi',
  'hey': 'hi',
  'please': 'kindly',
  'kindly': 'please',
  'maybe': 'perhaps',
  'perhaps': 'maybe',
  'till': 'until',
  'until': 'till',
  'almost': 'nearly',
  'nearly': 'almost',
  'buy': 'purchase',
  'purchase': 'buy',
  'everyone': 'everybody',
  'everybody': 'everyone',
  'someone': 'somebody',
  'somebody': 'someone',
  'anyone': 'anybody',
  'anybody': 'anyone',
  'nobody': 'no one',
  'toward': 'towards',
  'towards': 'toward',
  'afterward': 'afterwards',
  'afterwards': 'afterward',
  'among': 'amongst',
  'amongst': 'among',
  'whilst': 'while',
  'learned': 'learnt',
  'learnt': 'learned',
  'spelled': 'spelt',
  'spelt': 'spelled',
  'burned': 'burnt',
  'burnt': 'burned',
  'email': 'e-mail',
  'gray': 'grey',
  'grey': 'gray',
  // US <-> UK spellings (both are normal in Indian English).
  'organize': 'organise', 'organise': 'organize',
  'organized': 'organised', 'organised': 'organized',
  'organizing': 'organising', 'organising': 'organizing',
  'organization': 'organisation', 'organisation': 'organization',
  'realize': 'realise', 'realise': 'realize',
  'realized': 'realised', 'realised': 'realized',
  'recognize': 'recognise', 'recognise': 'recognize',
  'apologize': 'apologise', 'apologise': 'apologize',
  'prioritize': 'prioritise', 'prioritise': 'prioritize',
  'finalize': 'finalise', 'finalise': 'finalize',
  'finalized': 'finalised', 'finalised': 'finalized',
  'summarize': 'summarise', 'summarise': 'summarize',
  'analyze': 'analyse', 'analyse': 'analyze',
  'color': 'colour', 'colour': 'color',
  'favorite': 'favourite', 'favourite': 'favorite',
  'behavior': 'behaviour', 'behaviour': 'behavior',
  'center': 'centre', 'centre': 'center',
  'canceled': 'cancelled', 'cancelled': 'canceled',
  'traveling': 'travelling', 'travelling': 'traveling',
  'traveled': 'travelled', 'travelled': 'traveled',
  'labeled': 'labelled', 'labelled': 'labeled',
  'modeling': 'modelling', 'modelling': 'modeling',
  'enroll': 'enrol', 'enrol': 'enroll',
  'fulfill': 'fulfil', 'fulfil': 'fulfill',
  'judgment': 'judgement', 'judgement': 'judgment',
  'acknowledgment': 'acknowledgement',
  'acknowledgement': 'acknowledgment',
  'catalog': 'catalogue', 'catalogue': 'catalog',
  'defense': 'defence', 'defence': 'defense',
  'offense': 'offence', 'offence': 'offense',
};

/// Words that must not precede "please"/"kindly" (verb use: "to please").
const Set<String> _kPleaseVerbGuards = {
  'to',
  'will',
  'would',
  'can',
  'could',
  'should',
  'might',
  'must',
  'not',
};

/// Words after an "'s" contraction where "is" would be wrong ("it's been").
const Set<String> _kHasGuards = {'been', 'got', 'gotten', 'had'};

/// Hard limits. Keep in sync with the UI and the edge function.
const int kCanaryMaxSlots = 24;
const int kCanaryMaxCopies = 100;
const int kCanaryMinCopies = 2;

/// Invisible marker: WORD JOINER, 12 bits as ZERO WIDTH SPACE (0) /
/// ZERO WIDTH NON-JOINER (1), WORD JOINER. 10 data bits hold copyIndex + 1,
/// 2 check bits hold (number of 1-bits in the data) % 4.
final String _kZwEdge = String.fromCharCode(0x2060); // WORD JOINER
final String _kZwZero = String.fromCharCode(0x200B); // ZERO WIDTH SPACE
final String _kZwOne = String.fromCharCode(0x200C); // ZERO WIDTH NON-JOINER
/// Typographic apostrophe, as typed by phone keyboards.
final String _kCurlyQuote = String.fromCharCode(0x2019);

final RegExp _kZwMarker = RegExp('$_kZwEdge([$_kZwZero$_kZwOne]{12})$_kZwEdge');

final RegExp _kTokenPattern = RegExp(
  "[A-Za-z0-9'$_kCurlyQuote]+|[^A-Za-z0-9'$_kCurlyQuote]+",
);
final RegExp _kWordPattern = RegExp(
  "^[A-Za-z0-9'$_kCurlyQuote]+"
  r'$',
);
final RegExp _kWhitespaceOnly = RegExp(r'^\s+$');
final RegExp _kSafeAfter = RegExp(r'^(\s+|[,.!?;:]\s+|[,.!?;:]+$)');
final RegExp _kNotWordChar = RegExp(r"[^a-z0-9']+");
final RegExp _kSpaceRun = RegExp(r' +');

/// One swappable word inside the original note.
class CanarySlot {
  const CanarySlot({
    required this.tokenIndex,
    required this.original,
    required this.alternate,
    required this.left,
    required this.right,
  });

  /// Index into [CanaryPlan.tokens].
  final int tokenIndex;

  /// Lowercase original word (bit 0).
  final String original;

  /// Lowercase alternate wording (bit 1). May contain a space ("do not").
  final String alternate;

  /// Up to two normalized words before / after the slot (nearest first).
  final List<String> left;
  final List<String> right;

  Map<String, Object> toJson() => {
    'i': tokenIndex,
    'o': original,
    'a': alternate,
    'l': left,
    'r': right,
  };

  factory CanarySlot.fromJson(Map<String, dynamic> json) => CanarySlot(
    tokenIndex: json['i'] as int,
    original: json['o'] as String,
    alternate: json['a'] as String,
    left: (json['l'] as List).cast<String>(),
    right: (json['r'] as List).cast<String>(),
  );
}

/// The tokenized note plus its slots. Everything needed to render copies and
/// to match leaks. Stored only on the sender's device.
class CanaryPlan {
  const CanaryPlan({required this.tokens, required this.slots});

  final List<String> tokens;
  final List<CanarySlot> slots;

  int get bitCount => slots.length;

  Map<String, Object> toJson() => {
    't': tokens,
    's': [for (final s in slots) s.toJson()],
  };

  factory CanaryPlan.fromJson(Map<String, dynamic> json) => CanaryPlan(
    tokens: (json['t'] as List).cast<String>(),
    slots: [
      for (final s in json['s'] as List)
        CanarySlot.fromJson((s as Map).cast<String, dynamic>()),
    ],
  );
}

String _canonicalWord(String word) =>
    word.replaceAll(_kCurlyQuote, "'").toLowerCase();

/// Lowercases, maps curly apostrophes to straight ones, turns every other
/// non [a-z0-9'] character (including zero-width characters) into a space,
/// and collapses runs of spaces. Used on both leaks and slot options.
String canaryNormalize(String input) {
  final lower = input.replaceAll(_kCurlyQuote, "'").toLowerCase();
  final spaced = lower.replaceAll(_kNotWordChar, ' ');
  return spaced.trim().replaceAll(_kSpaceRun, ' ');
}

/// Finds the swappable words in [text]. Slots are at least three words apart
/// so that their context words are never slots themselves.
CanaryPlan buildCanaryPlan(String text) {
  final tokens = [for (final m in _kTokenPattern.allMatches(text)) m.group(0)!];
  final wordIndexes = <int>[
    for (var i = 0; i < tokens.length; i++)
      if (_kWordPattern.hasMatch(tokens[i])) i,
  ];

  final slots = <CanarySlot>[];
  var lastSlotWordPos = -1000;
  for (var w = 0; w < wordIndexes.length; w++) {
    if (slots.length >= kCanaryMaxSlots) break;
    if (w - lastSlotWordPos < 3) continue;

    final tokenIndex = wordIndexes[w];
    final key = _canonicalWord(tokens[tokenIndex]);
    final alternate = kCanaryAlternates[key];
    if (alternate == null) continue;

    // Separator guards: the word must stand alone, not be glued to symbols
    // ("2.5", "10:30", "(please", "ok.com").
    final before = tokenIndex > 0 ? tokens[tokenIndex - 1] : null;
    final after = tokenIndex + 1 < tokens.length
        ? tokens[tokenIndex + 1]
        : null;
    if (before != null && !_kWhitespaceOnly.hasMatch(before)) continue;
    if (after != null && !_kSafeAfter.hasMatch(after)) continue;

    final prevWord = w > 0 ? _canonicalWord(tokens[wordIndexes[w - 1]]) : '';
    final nextWord = w + 1 < wordIndexes.length
        ? _canonicalWord(tokens[wordIndexes[w + 1]])
        : '';
    if ((key == 'please' || key == 'kindly') &&
        _kPleaseVerbGuards.contains(prevWord)) {
      continue;
    }
    if (key.endsWith("'s") && _kHasGuards.contains(nextWord)) continue;

    final left = <String>[
      for (var k = w - 1; k >= 0 && k >= w - 2; k--)
        _canonicalWord(tokens[wordIndexes[k]]),
    ];
    final right = <String>[
      for (var k = w + 1; k < wordIndexes.length && k <= w + 2; k++)
        _canonicalWord(tokens[wordIndexes[k]]),
    ];
    slots.add(
      CanarySlot(
        tokenIndex: tokenIndex,
        original: key,
        alternate: alternate,
        left: left,
        right: right,
      ),
    );
    lastSlotWordPos = w;
  }
  return CanaryPlan(tokens: List.unmodifiable(tokens), slots: slots);
}

/// Smallest number of slots a note needs for [copyCount] copies.
///
/// Measured with the test harness: with 9 slots, a text mixed from two copies
/// named an innocent third reader in ~11% of trials; with 15 slots, ~0.2%.
/// So never go below 10, and add 5 on top of the bits needed to count copies.
int canaryRequiredSlots(int copyCount) {
  var bits = 0;
  while ((1 << bits) < copyCount + 1) {
    bits++;
  }
  return max(10, bits + 5);
}

/// Largest number of reader copies a plan supports at [canaryRequiredSlots].
int canaryMaxCopiesFor(CanaryPlan plan) {
  var best = 0;
  for (var copies = kCanaryMinCopies; copies <= kCanaryMaxCopies; copies++) {
    if (canaryRequiredSlots(copies) <= plan.bitCount) best = copies;
  }
  return best;
}

String _applyCase(String template, String replacement) {
  final letters = template.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.length >= 3 && letters == letters.toUpperCase()) {
    return replacement.toUpperCase();
  }
  if (letters.isNotEmpty &&
      letters[0] == letters[0].toUpperCase() &&
      letters[0] != letters[0].toLowerCase()) {
    return replacement.isEmpty
        ? replacement
        : replacement[0].toUpperCase() + replacement.substring(1);
  }
  return replacement;
}

String _zwMarker(int copyIndex) {
  final value = copyIndex + 1;
  final data = List<int>.generate(10, (b) => (value >> (9 - b)) & 1);
  final ones = data.where((b) => b == 1).length;
  final check = [(ones % 4) >> 1 & 1, (ones % 4) & 1];
  final bits = [...data, ...check];
  return _kZwEdge +
      bits.map((b) => b == 1 ? _kZwOne : _kZwZero).join() +
      _kZwEdge;
}

/// Returns the copy index hidden in [text] by [renderCanaryCopy], or null.
/// When several markers disagree, the most frequent valid value wins.
int? decodeCanaryMarker(String text) {
  final counts = <int, int>{};
  for (final m in _kZwMarker.allMatches(text)) {
    final bits = [
      for (final ch in m.group(1)!.split('')) ch == _kZwOne ? 1 : 0,
    ];
    var value = 0;
    for (var b = 0; b < 10; b++) {
      value = (value << 1) | bits[b];
    }
    final ones = bits.take(10).where((b) => b == 1).length;
    final check = (bits[10] << 1) | bits[11];
    if (check != ones % 4 || value == 0) continue;
    counts[value - 1] = (counts[value - 1] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.first.key;
}

/// The note's tokens with [codeword] applied (no invisible marker). Used by
/// [renderCanaryCopy] and by the "see the magic" view to highlight changes.
List<String> renderCanaryTokens(CanaryPlan plan, List<int> codeword) {
  if (codeword.length != plan.bitCount) {
    throw ArgumentError('codeword length must equal the number of slots');
  }
  final tokens = List<String>.of(plan.tokens);
  for (var k = 0; k < plan.slots.length; k++) {
    final slot = plan.slots[k];
    final chosen = codeword[k] == 0 ? slot.original : slot.alternate;
    tokens[slot.tokenIndex] = _applyCase(plan.tokens[slot.tokenIndex], chosen);
  }
  return tokens;
}

/// Renders the copy for [codeword]. When [copyIndex] is given, an invisible
/// marker carrying it is inserted after the 1st, 11th, 21st... word.
String renderCanaryCopy(CanaryPlan plan, List<int> codeword, {int? copyIndex}) {
  final tokens = renderCanaryTokens(plan, codeword);
  if (copyIndex == null) return tokens.join();

  final marker = _zwMarker(copyIndex);
  final out = StringBuffer();
  var wordCount = 0;
  for (final token in tokens) {
    out.write(token);
    if (_kWordPattern.hasMatch(token)) {
      wordCount++;
      if (wordCount % 10 == 1) out.write(marker);
    }
  }
  return out.toString();
}

/// Number of 1-bits in [value] (Hamming weight).
int _bitCountOf(int value) {
  var n = 0;
  for (var v = value; v != 0; v &= v - 1) {
    n++;
  }
  return n;
}

/// Random, distinct, non-zero codewords, spread apart where the slot count
/// allows (minimum distance 4, relaxed to 3, 2, then 1 if needed).
/// Throws [StateError] if the note has too few slots for [copyCount].
List<List<int>> generateCanaryCodewords(
  int copyCount,
  int bitCount, {
  Random? random,
}) {
  if (copyCount < kCanaryMinCopies || copyCount > kCanaryMaxCopies) {
    throw ArgumentError(
      'copyCount must be $kCanaryMinCopies..$kCanaryMaxCopies',
    );
  }
  if (bitCount > kCanaryMaxSlots) {
    throw ArgumentError('bitCount must be at most $kCanaryMaxSlots');
  }
  if (bitCount < canaryRequiredSlots(copyCount)) {
    throw StateError('Not enough swappable words for $copyCount copies.');
  }
  final rng = random ?? Random.secure();
  // Codewords are packed into ints (slot 0 = most significant bit) so the
  // distance check is one XOR and a bit count. Bits are drawn one at a time,
  // exactly as before, so a seeded Random still gives the same codewords.
  for (var minDistance = 4; minDistance >= 1; minDistance--) {
    final chosen = <int>[];
    var attempts = 0;
    while (chosen.length < copyCount && attempts < copyCount * 4000) {
      attempts++;
      var candidate = 0;
      for (var b = 0; b < bitCount; b++) {
        candidate = (candidate << 1) | rng.nextInt(2);
      }
      if (_bitCountOf(candidate) < minDistance) continue;
      if (chosen.every((c) => _bitCountOf(c ^ candidate) >= minDistance)) {
        chosen.add(candidate);
      }
    }
    if (chosen.length == copyCount) {
      return [
        for (final c in chosen)
          List<int>.generate(bitCount, (k) => (c >> (bitCount - 1 - k)) & 1),
      ];
    }
  }
  throw StateError('Could not spread copies apart. Add a few more words.');
}

enum CanaryMatchKind {
  /// The invisible marker named the copy exactly.
  exactMarker,

  /// Exactly one copy fits every readable fingerprint (5 or more readable).
  confident,

  /// One copy fits best, but either few fingerprints survived (3–4) or one of
  /// them disagrees (OCR/typing noise). Shown as "most likely".
  likely,

  /// The text matches the sender's own original, not any reader copy.
  senderOriginal,

  /// Several copies fit equally well: more of the leak is needed.
  ambiguous,

  /// Too little of the note survived to decide.
  notEnough,

  /// No single copy fits: edited, or combined from several copies. Never name
  /// anyone in this case.
  noMatch,
}

class CanaryMatch {
  const CanaryMatch({
    required this.kind,
    this.copyIndex,
    this.candidates = const [],
    this.agreeing = 0,
    this.known = 0,
  });

  final CanaryMatchKind kind;

  /// Set only for [CanaryMatchKind.exactMarker], [CanaryMatchKind.confident]
  /// and [CanaryMatchKind.likely]. The UI must not name a reader otherwise.
  final int? copyIndex;

  /// For [CanaryMatchKind.ambiguous]: the copies that fit equally well.
  final List<int> candidates;

  /// Fingerprints that agree with [copyIndex] out of [known] readable ones.
  final int agreeing;
  final int known;
}

/// Reads 0/1/null for every slot from a leaked text.
List<int?> readCanaryBits(String leakText, CanaryPlan plan) {
  final leak = ' ${canaryNormalize(leakText)} ';
  final result = <int?>[];
  for (final slot in plan.slots) {
    final a = canaryNormalize(slot.original);
    final b = canaryNormalize(slot.alternate);
    final l1 = slot.left.isNotEmpty ? slot.left[0] : null;
    final l2 = slot.left.length > 1 ? slot.left[1] : null;
    final r1 = slot.right.isNotEmpty ? slot.right[0] : null;
    final r2 = slot.right.length > 1 ? slot.right[1] : null;

    // Most specific context first. Each entry: words before, words after.
    final levels = <(List<String>, List<String>)>[
      if (l1 != null && l2 != null && r1 != null && r2 != null)
        ([l2, l1], [r1, r2]),
      if (l1 != null && r1 != null) ([l1], [r1]),
      if (l1 != null && l2 != null) ([l2, l1], const <String>[]),
      if (r1 != null && r2 != null) (const <String>[], [r1, r2]),
    ];

    int? bit;
    for (final (before, after) in levels) {
      String pattern(String option) =>
          ' ${[...before, option, ...after].join(' ')} ';
      final hasA = leak.contains(pattern(a));
      final hasB = leak.contains(pattern(b));
      if (hasA != hasB) {
        bit = hasA ? 0 : 1;
        break;
      }
      if (hasA && hasB) break; // Ambiguous at this level: give up on slot.
    }
    result.add(bit);
  }
  return result;
}

/// Works out which copy [leakText] came from.
CanaryMatch matchCanaryLeak(
  String leakText,
  CanaryPlan plan,
  List<List<int>> codewords,
) {
  final marker = decodeCanaryMarker(leakText);
  if (marker != null && marker >= 0 && marker < codewords.length) {
    return CanaryMatch(
      kind: CanaryMatchKind.exactMarker,
      copyIndex: marker,
      agreeing: plan.bitCount,
      known: plan.bitCount,
    );
  }

  final bits = readCanaryBits(leakText, plan);
  final known = bits.where((b) => b != null).length;
  if (known < 3) {
    return CanaryMatch(kind: CanaryMatchKind.notEnough, known: known);
  }

  int disagreeWith(List<int> code) {
    var n = 0;
    for (var k = 0; k < bits.length; k++) {
      if (bits[k] != null && bits[k] != code[k]) n++;
    }
    return n;
  }

  final perfect = <int>[
    for (var i = 0; i < codewords.length; i++)
      if (disagreeWith(codewords[i]) == 0) i,
  ];
  final zeroFits = disagreeWith(List<int>.filled(plan.bitCount, 0)) == 0;

  if (zeroFits && perfect.isEmpty) {
    return CanaryMatch(
      kind: CanaryMatchKind.senderOriginal,
      agreeing: known,
      known: known,
    );
  }
  if (perfect.length == 1) {
    return CanaryMatch(
      kind: known >= 5 ? CanaryMatchKind.confident : CanaryMatchKind.likely,
      copyIndex: perfect.single,
      agreeing: known,
      known: known,
    );
  }
  if (perfect.length > 1) {
    return CanaryMatch(
      kind: CanaryMatchKind.ambiguous,
      candidates: perfect,
      known: known,
    );
  }

  // No copy fits perfectly. Allow exactly one disagreement (a misread word),
  // but only when enough fingerprints survived and exactly one copy is that
  // close — otherwise refuse to name anyone.
  final nearlyPerfect = <int>[
    for (var i = 0; i < codewords.length; i++)
      if (disagreeWith(codewords[i]) == 1) i,
  ];
  if (known >= 8 && nearlyPerfect.length == 1 && !zeroFits) {
    return CanaryMatch(
      kind: CanaryMatchKind.likely,
      copyIndex: nearlyPerfect.single,
      agreeing: known - 1,
      known: known,
    );
  }
  return CanaryMatch(kind: CanaryMatchKind.noMatch, known: known);
}
