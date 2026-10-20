# @nosus/receipts (TypeScript)

Encode, parse, send and fetch NO SUS Canary receipts.

NO SUS Canary gives each reader a uniquely marked copy of a note. Every seal and every open is
written as one SPL Memo transaction on Solana. That memo is the receipt. This package reads and
writes it, so anyone can check a receipt without trusting the NO SUS server. The format is in
[docs/RECEIPTS_SPEC.md](../../docs/RECEIPTS_SPEC.md).

**Status:** v0.1 · devnet · not yet published to JSR/npm/pub.dev — use a path or git dependency.

## Install

Path, from a clone of this repo:

```ts
import { fetchReceipt } from "./packages/receipts-ts/mod.ts";
```

Git, pinned to a commit:

```ts
import { fetchReceipt } from "https://raw.githubusercontent.com/https-shubhamsahu/nosus-canary/<commit>/packages/receipts-ts/mod.ts";
```

Dependencies are pinned inline (`npm:@solana/kit@8.4.0`, `npm:@solana-program/memo@0.15.0`), so no
import map is needed. Only `sendMemo` uses them. `@solana/kit` pulls in `ws`, which reads
`WS_NO_BUFFER_UTIL` and `WS_NO_UTF_8_VALIDATE` when it loads, so a program that imports `mod.ts`
needs `--allow-env` for those two names.

## Usage

```ts
import { chainNoteId, encodeOpenMemo, explorerTxUrl, fetchReceipt } from "./mod.ts";

const sig =
  "2BHqnuCxYyemfegHkncgTsQyMPjpyB9boD1XqYfD1Wtbcf51Fpy3y264UwGhnvRKtcxFKCaSAzHxLrDwFRk512bQ";
const { receipt, feePayer } = await fetchReceipt(sig); // devnet unless you pass rpcUrl
console.log(receipt.t, receipt.note, feePayer, explorerTxUrl(sig));

// Is this the receipt for my note? noteId is the UUID in the reader link.
const mine = receipt.note === await chainNoteId("1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed");

// Build a memo. Throws ReceiptFormatError on a bad field.
const memo = encodeOpenMemo({ note: receipt.note, copy: 0, tag: "0x" + "ab".repeat(32) });
```

| Export                                                               | What it does                                                        |
| -------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `encodeSealMemo`, `encodeOpenMemo`                                   | Memo text, byte for byte as on chain.                               |
| `parseReceiptMemo`                                                   | Strict parse to `SealReceipt` or `OpenReceipt`, or throws.          |
| `chainNoteId`, `copyDigest`, `copiesHash`, `deviceHash`, `readerTag` | The hashes in the memo (async, WebCrypto).                          |
| `fetchReceipt`                                                       | One `getTransaction` call; returns slot, time, fee payer, receipt.  |
| `explorerTxUrl`                                                      | Solana Explorer link for a signature.                               |
| `parseRelayerKeys`, `sendMemo`                                       | Relayer side: parse keys and send a memo. Needs funded devnet keys. |

## CLI

```sh
deno run --allow-net packages/receipts-ts/cli.ts <signature> [--cluster devnet|mainnet-beta] [--rpc URL] [--note <uuid>]
```

It prints the decoded receipt and its Explorer link. With `--note`, it also checks that the memo's
`note` equals `chainNoteId(uuid)`. Exit codes: 0 ok, 1 receipt error or note mismatch, 2 bad usage.
The CLI does not load `@solana/kit`, so `--allow-net` is the only permission.

## Tests

From `packages/receipts-ts`:

```sh
deno test          # offline; uses ../test-vectors and saved devnet responses
deno check
deno lint
deno fmt --check
```

The Dart package tests against the same vectors in `packages/test-vectors`.

## License

Apache-2.0.
