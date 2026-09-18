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

  /// Monad transaction that sealed the note. Null until sealing succeeded.
  final String? sealTxHash;

  bool get isSealed => sealTxHash != null;

  CanaryOwnerRecord copyWith({String? sealTxHash, DateTime? expiresAt}) =>
      CanaryOwnerRecord(
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
      plan: CanaryPlan.fromJson(
        (json['plan'] as Map).cast<String, dynamic>(),
      ),
      codewords: [
        for (final c in json['codewords'] as List)
          [for (final ch in (c as String).split('')) ch == '1' ? 1 : 0],
      ],
      sealTxHash: json['sealTxHash'] as String?,
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
  });

  final int copyIndex;
  final String readerName;
  final DateTime openedAt;

  /// Null while the Monad record is still being written.
  final String? openTxHash;
}

class CanaryNoteStatus {
  const CanaryNoteStatus({
    required this.copyCount,
    required this.sealTxHash,
    required this.expiresAt,
    required this.copies,
  });

  final int copyCount;
  final String? sealTxHash;
  final DateTime expiresAt;

  /// Only copies that have been opened, ordered by copy index.
  final List<CanaryCopyStatus> copies;

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
  });

  /// The copy text, including its invisible marker.
  final String text;
  final int copyIndex;
  final int copyCount;
  final String readerName;
  final DateTime openedAt;

  /// Null only in the rare case the Monad write succeeded but its hash was
  /// not stored; the UI then shows the time without a proof link.
  final String? openTxHash;
}
