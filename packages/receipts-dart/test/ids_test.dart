import 'package:nosus_receipts/nosus_receipts.dart';
import 'package:test/test.dart';

import 'vectors.dart';

void main() {
  test('chainNoteId', () {
    for (final v in section('chainNoteId')) {
      expect(chainNoteId(v['noteId'] as String), v['expected']);
    }
  });

  test('deviceHash', () {
    for (final v in section('deviceHash')) {
      expect(deviceHash(v['deviceId'] as String), v['expected']);
    }
  });

  test('copyDigest hashes the copy text as UTF-8', () {
    for (final v in section('copyDigest')) {
      expect(
        copyDigest(
          v['saltHex'] as String,
          v['index'] as int,
          v['copyText'] as String,
        ),
        v['expected'],
      );
    }
  });

  test('copiesHash', () {
    for (final v in section('copiesHash')) {
      expect(copiesHash((v['digests'] as List).cast<String>()), v['expected']);
    }
  });

  test('readerTag', () {
    for (final v in section('readerTag')) {
      expect(
        readerTag(
          tagSalt: v['tagSalt'] as String,
          noteId: v['noteId'] as String,
          copyIndex: v['copyIndex'] as int,
          deviceHash: v['deviceHash'] as String,
        ),
        v['expected'],
      );
    }
  });

  test('explorerTxUrl: devnet has a cluster param, mainnet has none', () {
    for (final v in section('explorerTxUrl')) {
      final cluster = SolanaCluster.byId(v['cluster'] as String)!;
      expect(
        explorerTxUrl(v['signature'] as String, cluster: cluster),
        v['expected'],
      );
    }
    expect(
      explorerTxUrl('abc'),
      'https://explorer.solana.com/tx/abc?cluster=devnet',
    );
    expect(SolanaCluster.byId('testnet'), isNull);
  });
}
