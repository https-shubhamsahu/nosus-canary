import 'package:uuid/uuid.dart';

import '../../../core/utils/web_links.dart';
import '../domain/canary_fingerprint.dart';
import '../domain/canary_link.dart';
import '../domain/canary_models.dart';
import 'canary_api.dart';
import 'canary_crypto.dart';
import 'canary_store.dart';

/// The only entry point the Canary screens use (no widget talks to the API,
/// the store or the crypto helpers directly).
class CanaryRepository {
  CanaryRepository(this._store, {CanaryApi? api}) : _api = api ?? CanaryApi();

  final CanaryStore _store;
  final CanaryApi _api;

  static const int maxNoteLength = 1500;
  static const int maxReaderNameLength = 40;

  List<CanaryOwnerRecord> listNotes() => _store.loadNotes();

  CanaryOwnerRecord? findNote(String noteId) => _store.findNote(noteId);

  /// Sender: builds every copy on this device, uploads only ciphertext, and
  /// seals the note on Monad. [onStage] receives short progress messages.
  Future<CanaryOwnerRecord> createNote({
    required String text,
    required int copyCount,
    required int expiresInHours,
    void Function(String stage)? onStage,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const CanaryUserException('Write the note first.');
    }
    if (trimmed.length > maxNoteLength) {
      throw const CanaryUserException(
        'Keep the note under $maxNoteLength characters.',
      );
    }
    final plan = buildCanaryPlan(trimmed);
    final required = canaryRequiredSlots(copyCount);
    if (plan.bitCount < required) {
      throw CanaryUserException(
        'Canary found ${plan.bitCount} of the $required swappable words it '
        'needs for $copyCount readers. Add a sentence or two, or choose fewer readers.',
      );
    }

    onStage?.call('Making $copyCount unique copies…');
    final codewords = generateCanaryCodewords(copyCount, plan.bitCount);
    final noteId = const Uuid().v4();
    final keyHex = CanaryCrypto.randomHex(32);
    final saltHex = CanaryCrypto.randomHex(32);
    final ownerSecret = CanaryCrypto.randomHex(32);

    final encrypted = <({int index, String ciphertext, String iv})>[];
    final digests = <String>[];
    for (var i = 0; i < copyCount; i++) {
      final copyText = renderCanaryCopy(plan, codewords[i], copyIndex: i);
      final sealed = CanaryCrypto.encrypt(copyText, keyHex);
      encrypted.add((index: i, ciphertext: sealed.ciphertextB64, iv: sealed.ivHex));
      digests.add(CanaryCrypto.copyDigest(saltHex, i, copyText));
    }

    final (:origin, :basePath) = webShareLinkBase();
    final firstLine = trimmed.split('\n').first;
    final draft = CanaryOwnerRecord(
      noteId: noteId,
      keyHex: keyHex,
      ownerSecret: ownerSecret,
      saltHex: saltHex,
      copyCount: copyCount,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(hours: expiresInHours)),
      readerLink: buildCanaryReaderLink(
        origin: origin,
        basePath: basePath,
        noteId: noteId,
        keyHex: keyHex,
      ),
      preview: firstLine.length > 80
          ? '${firstLine.substring(0, 77)}…'
          : firstLine,
      plan: plan,
      codewords: codewords,
    );
    // Save first so a crash after the upload never loses the only copy of
    // the codewords. Removed again below if the upload fails.
    await _store.saveNote(draft);

    onStage?.call('Sealing on Monad…');
    try {
      final result = await _api.create(
        noteId: noteId,
        ownerHash: CanaryCrypto.sha256Hex(ownerSecret),
        copyCount: copyCount,
        copiesHash: CanaryCrypto.copiesHash(digests),
        expiresInHours: expiresInHours,
        copies: encrypted,
      );
      final sealed = draft.copyWith(
        sealTxHash: result.sealTxHash,
        expiresAt: result.expiresAt,
      );
      await _store.saveNote(sealed);
      return sealed;
    } catch (_) {
      await _store.deleteNote(noteId);
      rethrow;
    }
  }

  /// Reader: gets (or re-gets) this device's copy and decrypts it locally.
  Future<CanaryOpenedCopy> openCopy({
    required String noteId,
    required String keyHex,
    required String readerName,
  }) async {
    final name = readerName.trim();
    if (name.isEmpty) {
      throw const CanaryUserException('Type your name first.');
    }
    if (name.length > maxReaderNameLength) {
      throw const CanaryUserException(
        'Use a shorter name ($maxReaderNameLength characters max).',
      );
    }
    final deviceId = await _store.deviceId();
    final result = await _api.open(
      noteId: noteId,
      deviceId: deviceId,
      readerName: name,
    );
    final String text;
    try {
      text = CanaryCrypto.decrypt(result.ciphertext, result.iv, keyHex);
    } catch (_) {
      throw const CanaryUserException(
        'This link is incomplete or damaged. Ask for the link again.',
      );
    }
    await _store.rememberReaderName(name);
    return CanaryOpenedCopy(
      text: text,
      copyIndex: result.copyIndex,
      copyCount: result.copyCount,
      readerName: name,
      openedAt: result.openedAt,
      openTxHash: result.openTxHash,
    );
  }

  String? lastReaderName() => _store.lastReaderName();

  Future<CanaryNoteStatus> fetchStatus(CanaryOwnerRecord record) =>
      _api.status(noteId: record.noteId, ownerSecret: record.ownerSecret);

  /// Runs entirely on this device; the leaked text is never uploaded.
  CanaryMatch checkLeak(CanaryOwnerRecord record, String leakText) =>
      matchCanaryLeak(leakText, record.plan, record.codewords);

  Future<void> forgetNote(String noteId) => _store.deleteNote(noteId);
}
