import 'canary_fingerprint.dart';

/// A problem the person can fix or should read (shown as-is in the UI).
class CanaryUserException implements Exception {
  const CanaryUserException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Everything the sender's device keeps about one Canary note.
///
/// Stored only on the device that created the note (SharedPreferences). It
/// holds the key, the salt and every codeword, so it must never be uploaded.
class CanaryOwnerRecord {
  const CanaryOwnerRecord({
    required this.noteId,
    required this.keyHex,
    required this.ownerSecret,
    required this.saltHex,
    required this.copyCount,
    required this.createdAt,
    required this.expiresAt,
    required this.readerLink,
    required this.preview,
    required this.plan,
    required this.codewords,
    this.sealTxHash,
    this.sealSolanaSig,
  });

  final String noteId;
  final String keyHex;

  /// 64 hex chars. The server only stores sha256(ownerSecret).
  final String ownerSecret;

  /// 64 hex chars mixed into every copy digest (never leaves the device).
  final String saltHex;
  final int copyCount;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String readerLink;

  /// First line of the note, max 80 characters, for the list screen.
  final String preview;
  final CanaryPlan plan;

  /// codewords[i] is the 0/1 choice per slot for copy i.
  final List<List<int>> codewords;

  /// Monad testnet transaction that sealed the note (earlier prototype).
  /// Null while the server has Monad off, and for unsealed drafts.
  final String? sealTxHash;

  /// Solana devnet memo signature that sealed the note: the product's
  /// receipt. Null for unsealed drafts and for records saved before Solana
  /// proofs existed.
  final String? sealSolanaSig;

  /// Sealed once either chain holds the seal.
  bool get isSealed => sealTxHash != null || sealSolanaSig != null;

  CanaryOwnerRecord copyWith({
    String? sealTxHash,
    String? sealSolanaSig,
    DateTime? expiresAt,
  }) => CanaryOwnerRecord(
    noteId: noteId,
    keyHex: keyHex,
    ownerSecret: ownerSecret,
    saltHex: saltHex,
    copyCount: copyCount,
    createdAt: createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    readerLink: readerLink,
    preview: preview,
    plan: plan,
    codewords: codewords,
    sealTxHash: sealTxHash ?? this.sealTxHash,
    sealSolanaSig: sealSolanaSig ?? this.sealSolanaSig,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'noteId': noteId,
    'keyHex': keyHex,
    'ownerSecret': ownerSecret,
    'saltHex': saltHex,
    'copyCount': copyCount,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'readerLink': readerLink,
    'preview': preview,
    'plan': plan.toJson(),
    'codewords': [for (final c in codewords) c.join()],
    'sealTxHash': sealTxHash,
    'sealSolanaSig': sealSolanaSig,
  };

  factory CanaryOwnerRecord.fromJson(Map<String, dynamic> json) {
    if (json['v'] != 1) throw const FormatException('Unknown record version');
    return CanaryOwnerRecord(
      noteId: json['noteId'] as String,
      keyHex: json['keyHex'] as String,
      ownerSecret: json['ownerSecret'] as String,
      saltHex: json['saltHex'] as String,
      copyCount: json['copyCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      readerLink: json['readerLink'] as String,
      preview: json['preview'] as String,
      plan: CanaryPlan.fromJson((json['plan'] as Map).cast<String, dynamic>()),
      codewords: [
        for (final c in json['codewords'] as List)
          [for (final ch in (c as String).split('')) ch == '1' ? 1 : 0],
      ],
      sealTxHash: json['sealTxHash'] as String?,
      // Records saved before Solana proofs existed have no key here.
      sealSolanaSig: json['sealSolanaSig'] as String?,
    );
  }
}

/// One reader copy as the owner dashboard sees it.
class CanaryCopyStatus {
  const CanaryCopyStatus({
    required this.copyIndex,
    required this.readerName,
    required this.openedAt,
    required this.openTxHash,
    required this.openSolanaSig,
  });

  final int copyIndex;
  final String readerName;
  final DateTime openedAt;

  /// Monad testnet transaction for this open. Null while it is being
  /// written, and always null while the server has Monad off.
  final String? openTxHash;

  /// Solana devnet memo signature for this open. Null while it is being
  /// written (a failed memo is sent again on the reader's next open).
  final String? openSolanaSig;

  /// The open has a public receipt on at least one chain.
  bool get isRecorded => openTxHash != null || openSolanaSig != null;
}

class CanaryNoteStatus {
  const CanaryNoteStatus({
    required this.copyCount,
    required this.sealTxHash,
    required this.sealSolanaSig,
    required this.expiresAt,
    required this.copies,
  });

  final int copyCount;

  /// Monad testnet transaction that sealed the note. Null while the server
  /// has Monad off.
  final String? sealTxHash;

  /// Solana devnet memo signature that sealed the note.
  final String? sealSolanaSig;
  final DateTime expiresAt;

  /// Only copies that have been opened, ordered by copy index.
  final List<CanaryCopyStatus> copies;

  /// Nothing more can change: every copy is opened and recorded on chain,
  /// or the link has expired. Screens stop polling at this point.
  bool get isSettled =>
      !expiresAt.isAfter(DateTime.now()) ||
      (copies.length >= copyCount && copies.every((c) => c.isRecorded));

  CanaryCopyStatus? copy(int index) {
    for (final c in copies) {
      if (c.copyIndex == index) return c;
    }
    return null;
  }
}

/// What a reader receives after opening their copy.
class CanaryOpenedCopy {
  const CanaryOpenedCopy({
    required this.text,
    required this.copyIndex,
    required this.copyCount,
    required this.readerName,
    required this.openedAt,
    required this.openTxHash,
    required this.openSolanaSig,
  });

  /// The copy text, including its invisible marker.
  final String text;
  final int copyIndex;
  final int copyCount;
  final String readerName;
  final DateTime openedAt;

  /// Monad testnet transaction for this open (earlier prototype). Null
  /// while the server has Monad off.
  final String? openTxHash;

  /// Solana devnet memo signature for this open. Null when the memo has not
  /// landed yet (it is sent again on the next open of this copy); the UI
  /// then shows the time without a proof link.
  final String? openSolanaSig;
}
