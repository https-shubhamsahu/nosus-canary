import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/canary/domain/canary_fingerprint.dart';
import 'package:no_sus/features/canary/domain/canary_models.dart';

const _noteId = '1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed';
final _monadHash = '0x${'ab' * 32}';
final _solanaSig = '5' * 88;

CanaryOwnerRecord _record({String? sealTxHash, String? sealSolanaSig}) =>
    CanaryOwnerRecord(
      noteId: _noteId,
      keyHex: 'cd' * 32,
      ownerSecret: 'ef' * 32,
      saltHex: '01' * 32,
      copyCount: 2,
      createdAt: DateTime.utc(2026, 10, 10, 12),
      expiresAt: DateTime.utc(2026, 10, 11, 12),
      readerLink: 'https://x.y/#/canary/$_noteId?k=${'cd' * 32}',
      preview: 'The quick brown fox jumps over the lazy dog.',
      plan: buildCanaryPlan(
        'The quick brown fox jumps over the lazy dog. '
        'It was a very big and really nice day for a walk.',
      ),
      codewords: const [
        [0, 1, 0],
        [1, 0, 1],
      ],
      sealTxHash: sealTxHash,
      sealSolanaSig: sealSolanaSig,
    );

void main() {
  test('owner record round-trips with both proofs', () {
    final original = _record(
      sealTxHash: _monadHash,
      sealSolanaSig: _solanaSig,
    );
    final json = original.toJson();
    expect(json['v'], 1);
    expect(json['sealTxHash'], _monadHash);
    expect(json['sealSolanaSig'], _solanaSig);

    final restored = CanaryOwnerRecord.fromJson(json);
    expect(restored.noteId, original.noteId);
    expect(restored.sealTxHash, _monadHash);
    expect(restored.sealSolanaSig, _solanaSig);
    expect(restored.codewords, original.codewords);
    expect(restored.isSealed, isTrue);
  });

  test('owner record round-trips without a Solana proof', () {
    final original = _record(sealTxHash: _monadHash);
    final json = original.toJson();
    expect(json.containsKey('sealSolanaSig'), isTrue);
    expect(json['sealSolanaSig'], isNull);

    final restored = CanaryOwnerRecord.fromJson(json);
    expect(restored.sealTxHash, _monadHash);
    expect(restored.sealSolanaSig, isNull);
    // A Monad seal alone still counts, so records from the Monad build
    // keep working.
    expect(restored.isSealed, isTrue);
  });

  test('records saved before Solana proofs load with a null signature', () {
    final legacy = _record(sealTxHash: _monadHash).toJson()
      ..remove('sealSolanaSig');
    expect(legacy.containsKey('sealSolanaSig'), isFalse);

    final restored = CanaryOwnerRecord.fromJson(legacy);
    expect(restored.sealTxHash, _monadHash);
    expect(restored.sealSolanaSig, isNull);
    expect(restored.isSealed, isTrue);
  });

  test('copyWith adds the Solana proof without dropping the Monad one', () {
    final draft = _record();
    expect(draft.isSealed, isFalse);

    final sealed = draft.copyWith(
      sealTxHash: _monadHash,
      sealSolanaSig: _solanaSig,
    );
    expect(sealed.sealTxHash, _monadHash);
    expect(sealed.sealSolanaSig, _solanaSig);

    final untouched = sealed.copyWith(expiresAt: DateTime.utc(2027));
    expect(untouched.sealTxHash, _monadHash);
    expect(untouched.sealSolanaSig, _solanaSig);
  });

  test('note status settles on Monad alone', () {
    final future = DateTime.now().add(const Duration(days: 1));
    final status = CanaryNoteStatus(
      copyCount: 1,
      sealTxHash: _monadHash,
      sealSolanaSig: null,
      expiresAt: future,
      copies: [
        CanaryCopyStatus(
          copyIndex: 0,
          readerName: 'Sam',
          openedAt: DateTime.now(),
          openTxHash: _monadHash,
          openSolanaSig: null,
        ),
      ],
    );
    expect(status.isSettled, isTrue);
    expect(status.copy(0)?.openSolanaSig, isNull);
  });

  test('a Solana-only seal counts as sealed (Monad off)', () {
    final record = _record(sealSolanaSig: _solanaSig);
    expect(record.sealTxHash, isNull);
    expect(record.isSealed, isTrue);

    final restored = CanaryOwnerRecord.fromJson(record.toJson());
    expect(restored.sealTxHash, isNull);
    expect(restored.sealSolanaSig, _solanaSig);
    expect(restored.isSealed, isTrue);
  });

  CanaryCopyStatus copy({String? tx, String? sig}) => CanaryCopyStatus(
    copyIndex: 0,
    readerName: 'Sam',
    openedAt: DateTime.now(),
    openTxHash: tx,
    openSolanaSig: sig,
  );

  CanaryNoteStatus status(CanaryCopyStatus c) => CanaryNoteStatus(
    copyCount: 1,
    sealTxHash: null,
    sealSolanaSig: _solanaSig,
    expiresAt: DateTime.now().add(const Duration(days: 1)),
    copies: [c],
  );

  test('a copy is recorded by either chain', () {
    expect(copy().isRecorded, isFalse);
    expect(copy(tx: _monadHash).isRecorded, isTrue);
    expect(copy(sig: _solanaSig).isRecorded, isTrue);
  });

  test('note status settles on Solana alone (Monad off)', () {
    expect(status(copy(sig: _solanaSig)).isSettled, isTrue);
    // The open memo has not landed yet: keep polling.
    expect(status(copy()).isSettled, isFalse);
  });
}
