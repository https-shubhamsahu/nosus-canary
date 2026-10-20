# nosus_receipts (Dart)

Encode, parse and fetch NO SUS Canary receipts. Pure Dart; works in Flutter apps and on the
command line.

NO SUS Canary gives each reader a uniquely marked copy of a note. Every seal and every open is
written as one SPL Memo transaction on Solana. That memo is the receipt. This package reads and
writes it, so anyone can check a receipt without trusting the NO SUS server. The format is in
[docs/RECEIPTS_SPEC.md](../../docs/RECEIPTS_SPEC.md).

**Status:** v0.1 · devnet · not yet published to JSR/npm/pub.dev — use a path or git dependency.

## Install

Path, from a clone of this repo:

```yaml
dependencies:
  nosus_receipts:
    path: ../packages/receipts-dart
```

Git:

```yaml
dependencies:
  nosus_receipts:
    git:
      url: https://github.com/https-shubhamsahu/nosus-canary.git
      path: packages/receipts-dart
      ref: <commit>
```

Dependencies: `crypto` and `http` only. Needs Dart 3.13 or newer.

## Usage

```dart
import 'package:nosus_receipts/nosus_receipts.dart';

final client = SolanaReceiptClient(SolanaCluster.devnet.rpcUrl);
final r = await client.fetch('2BHqnuCxYyemfegHkncgTsQyMPjpyB9boD1XqYfD1Wtbcf51Fpy3y264UwGhnvRKtcxFKCaSAzHxLrDwFRk512bQ');
client.close();

// Is this the receipt for my note? noteId is the UUID in the reader link.
final mine = r.receipt.note == chainNoteId('1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed');
final text = switch (r.receipt) {
  SealReceipt(:final copies) => 'sealed, $copies copies',
  OpenReceipt(:final copy) => 'copy $copy opened',
};
print('$text ${explorerTxUrl(r.signature)}');
```

- `SealReceipt` / `OpenReceipt`: `encode()` gives the memo text byte for byte as on chain. The
  constructors throw `ReceiptFormatException` on a bad field.
- `ReceiptMemo.parse(memo)`: strict parse, or throws `ReceiptFormatException`.
- `chainNoteId`, `copyDigest`, `copiesHash`, `deviceHash`, `readerTag`: the hashes in the memo.
- `SolanaReceiptClient.fetch(signature)`: one `getTransaction` call. Throws
  `ReceiptFetchException` when the transaction is missing, failed, or has no NO SUS memo.
- `explorerTxUrl(signature, cluster: ...)`: Solana Explorer link.

Sending memos is not in this package. The relayer is TypeScript (`packages/receipts-ts`).

## CLI

From `packages/receipts-dart`:

```sh
dart run bin/verify.dart <signature> [--cluster devnet|mainnet-beta] [--rpc URL] [--note <uuid>]
```

It prints the decoded receipt and its Explorer link. With `--note`, it also checks that the
memo's `note` equals `chainNoteId(uuid)`. Exit codes: 0 ok, 1 receipt error or note mismatch, 2
bad usage. Same output as the TypeScript CLI.

## Tests

From `packages/receipts-dart`:

```sh
dart pub get
dart analyze
dart format --set-exit-if-changed .
dart test          # offline; uses ../test-vectors and saved devnet responses
```

The TypeScript package tests against the same vectors in `packages/test-vectors`.

## License

Apache-2.0.
