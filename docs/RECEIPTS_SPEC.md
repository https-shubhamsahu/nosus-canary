# NO SUS Canary receipts: memo format v1

A receipt is one Solana transaction with one SPL Memo instruction. The memo text says what
happened: a note was sealed, or one copy of it was opened. There is one receipt per seal and one
per open.

The relayer (the Canary edge function) pays for and signs every receipt. Readers need no wallet.

Code: [packages/receipts-ts](../packages/receipts-ts) (TypeScript, also used by the relayer) and
[packages/receipts-dart](../packages/receipts-dart). Both test against
[packages/test-vectors/receipts.json](../packages/test-vectors/receipts.json).

## Where receipts live

- Cluster: Solana devnet.
- Memo program: `MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr` (SPL Memo v3). Readers also accept
  `Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo` (SPL Memo v1) and
  `Memo4c2pN8afCj432Lb7RMVKi9PbQnnW7ewFFaV3oAH` (p-memo).
- Relayer: `CCD4SUQt4No2QNidpCuNAxJZXsqY1KhxkpfkuphueQJx`. It pays the fee and signs the memo.

## Memo text

Compact JSON: UTF-8, no spaces, keys in exactly this order.

```text
seal: {"p":"nosus-canary","v":1,"t":"seal","note":"0x<64 hex>","copies":N,"hash":"0x<64 hex>","exp":E}
open: {"p":"nosus-canary","v":1,"t":"open","note":"0x<64 hex>","copy":N,"tag":"0x<64 hex>"}
```

| Key      | In   | Value                      | Meaning                                          |
| -------- | ---- | -------------------------- | ------------------------------------------------ |
| `p`      | both | `"nosus-canary"`           | Protocol name.                                   |
| `v`      | both | `1`                        | Format version.                                  |
| `t`      | both | `"seal"` or `"open"`       | What happened.                                   |
| `note`   | both | bytes32                    | Which note: `chainNoteId`.                       |
| `copies` | seal | integer                    | How many marked copies (2 to 100 today).         |
| `hash`   | seal | bytes32                    | Commitment to every copy: `copiesHash`.          |
| `exp`    | seal | integer                    | Expiry in unix seconds. `0` means never.         |
| `copy`   | open | integer                    | Which copy was opened, counting from 0.          |
| `tag`    | open | bytes32                    | Which device opened it, as a salted hash.        |

- bytes32 is `0x` followed by exactly 64 lowercase hex characters.
- Integers are non-negative, at most 2^53 − 1, with no sign, decimal point or exponent.
- A reader must reject any memo that is not byte for byte what an encoder would write. That
  includes another key order, extra or missing keys, whitespace, uppercase hex and `3.0`. The
  simple way: parse, check each field, encode again, and compare the strings.

Real example (seal `2BHqnuCx…512bQ`, 217 bytes):

```json
{"p":"nosus-canary","v":1,"t":"seal","note":"0xe5bbe8d0602b1dfda55ea516343e6a5064d021c37e6b7ba648bc5719aea1fc40","copies":3,"hash":"0x2a1ab6e3b5fae89ea53b689e88c9f6560d2b33711e36cc1d4524df6c680271e8","exp":1791634855}
```

## How each value is computed

Every hash is SHA-256 over UTF-8 text, written as lowercase hex. `+` joins strings. Numbers are
written in decimal.

| Value           | Formula                                                                  | Who can recompute it                 |
| --------------- | ------------------------------------------------------------------------ | ------------------------------------ |
| `note`          | `"0x" + sha256("nosus-canary:" + noteId)`                                | Anyone with the note's UUID.         |
| copy digest     | `sha256(salt + ":" + index + ":" + copyText)`                            | The note owner.                      |
| `hash`          | `"0x" + sha256(digest_0 + digest_1 + … + digest_n-1)`, no separator      | The note owner.                      |
| device hash     | `sha256("device:" + deviceId)`                                           | The relayer. Never on chain.         |
| `tag`           | `"0x" + sha256(tagSalt + ":" + noteId + ":" + copy + ":" + deviceHash)`  | The relayer only.                    |

- `noteId` is the lowercase UUID in the reader link (`…/#/canary/<noteId>?k=…`).
- `salt` is 32 random bytes as hex. It and every copy text stay on the owner's device.
- `tagSalt` is a secret the relayer holds. Without it a tag says nothing about the device.

## What is never on chain

- Note text and copy text, in any form other than the hashes above.
- Keys: the note's AES key (it stays in the link fragment), relayer keys, salts.
- Names: reader names and owner names.
- Device ids. Only the salted `tag` is written.

## Size

A seal memo is at most 219 bytes today (100 copies, a 10-digit `exp`). An open memo is at most 198
bytes. Readers reject anything over 566 bytes, the most a single-signer memo transaction can
carry.

## Verify a receipt by hand

1. Open the transaction on Solana Explorer:
   `https://explorer.solana.com/tx/<signature>?cluster=devnet`.
2. Check that it succeeded, that the program is a Memo program from the table above, and that
   the signer is the relayer.
3. Read the memo text. Check it has the exact shape above.
4. Recompute `note` from the note's UUID and compare:

   ```sh
   printf '%s' 'nosus-canary:<noteId>' | sha256sum   # macOS: shasum -a 256
   ```

   Put `0x` in front of the result. It must equal `note`.
5. For a seal, check `copies` and `exp`. For an open, `copy` tells you which marked copy was
   opened.

Or let a CLI do steps 1 to 4:

```sh
deno run --allow-net packages/receipts-ts/cli.ts <signature> --note <noteId>
dart run bin/verify.dart <signature> --note <noteId>   # from packages/receipts-dart
```

## Versioning

- `v` goes up on any field change: a field added, removed, renamed or moved, a new meaning, or a
  new hash formula.
- A reader for one version rejects every other version.
- A new version gets new vectors in `packages/test-vectors`. Old vectors stay, so old receipts
  still verify.
- Package versions (0.1.0 today) are separate from `v`.
