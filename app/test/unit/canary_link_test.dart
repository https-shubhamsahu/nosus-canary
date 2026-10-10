import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/canary/domain/canary_link.dart';
import 'package:no_sus/main.dart' show extractBurnNoteToken, extractCanaryToken;

const _noteId = '1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed';
final _key = 'ab' * 32;

void main() {
  test('reader link round-trips', () {
    final link = buildCanaryReaderLink(
      origin: 'https://https-shubhamsahu.github.io',
      basePath: '/nosus-canary',
      noteId: _noteId,
      keyHex: _key,
    );
    expect(
      link,
      'https://https-shubhamsahu.github.io/nosus-canary/#/canary/$_noteId?k=$_key',
    );
    final token = parseCanaryReaderLink(link);
    expect(token, isNotNull);
    expect(token!.noteId, _noteId);
    expect(token.keyHex, _key);
  });

  test('rejects wrong shapes', () {
    expect(parseCanaryReaderLink('https://x.y/#/canary/$_noteId'), isNull);
    expect(
      parseCanaryReaderLink('https://x.y/#/canary/$_noteId?k=abc'),
      isNull,
    );
    expect(
      parseCanaryReaderLink('https://x.y/#/canary/not-a-uuid?k=$_key'),
      isNull,
    );
    expect(
      parseCanaryReaderLink('https://x.y/canary/$_noteId?k=$_key'),
      isNull,
    );
    expect(
      parseCanaryReaderLink(
        'https://x.y/#/burn/$_noteId?k=$_key&v=${'cd' * 16}',
      ),
      isNull,
    );
  });

  test('Canary and Burn extractors never claim each other\'s links', () {
    final canary = Uri.parse('https://x.y/#/canary/$_noteId?k=$_key');
    final burn = Uri.parse(
      'https://x.y/#/burn/$_noteId?k=$_key&v=${'cd' * 16}',
    );
    expect(extractCanaryToken(canary)?.noteId, _noteId);
    expect(extractBurnNoteToken(canary), isNull);
    expect(extractCanaryToken(burn), isNull);
  });

  test('chain note id is a stable 32-byte hex value', () {
    final id = canaryChainNoteId(_noteId);
    expect(id, matches(RegExp(r'^0x[0-9a-f]{64}$')));
    expect(canaryChainNoteId(_noteId), id);
    // Must equal sha256("nosus-canary:" + noteId); the edge function computes
    // the same value. Known answer (also used to test the edge function):
    expect(
      id,
      '0xb8168efcc5c17afc454283c0e2237b39f5dc917d39ab0eb0f540f544b9878f2e',
    );
  });

  test('explorer links point at the right testnet per chain', () {
    final monadHash = '0x${'ab' * 32}';
    // Base58 Solana signatures are 86–88 chars; this one is 88.
    final solanaSig = '5' * 88;

    expect(
      canaryExplorerTxUrl(monadHash),
      'https://testnet.monadscan.com/tx/$monadHash',
    );
    expect(
      canarySolanaExplorerTxUrl(solanaSig),
      'https://explorer.solana.com/tx/$solanaSig?cluster=devnet',
    );
    expect(CanaryChain.monad.txUrl(monadHash), canaryExplorerTxUrl(monadHash));
    expect(
      CanaryChain.solana.txUrl(solanaSig),
      canarySolanaExplorerTxUrl(solanaSig),
    );
  });

  test('chain labels read correctly in chips and sentences', () {
    expect(CanaryChain.monad.label, 'Monad');
    expect(CanaryChain.solana.label, 'Solana');
    expect(CanaryChain.monad.network, 'Monad testnet');
    expect(CanaryChain.solana.network, 'Solana devnet');
  });
}
