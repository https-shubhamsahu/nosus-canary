# Security

## Reporting a problem

Email **shubhamsahu@nosus.foo** with "security" in the subject. Please don't open a public issue
for a vulnerability. The demo runs on Solana devnet and a test
backend; never put real secrets or personal data into it.

## What goes where

| Data | Sender's device | Link | Server (Supabase) | Solana (public) |
|---|---|---|---|---|
| Note text and every copy | ✅ | — | encrypted only | — |
| AES-256 key | ✅ | in the `#fragment` | — | — |
| Fingerprint of each copy (which words were swapped) | ✅ | — | — | — |
| Owner secret (unlocks the dashboard) | ✅ | — | stored as sha256 only | — |
| Reader's typed name, open time | shown on dashboard | — | ✅ | — |
| Reader's device id (random, per browser) | — | — | stored as sha256 only | — |
| Note id | ✅ | ✅ | ✅ | sha256 only |
| Commitment to all copies | ✅ | — | ✅ | ✅ |
| Which copy was opened | ✅ | — | ✅ | ✅ |
| Reader tag | — | — | ✅ | ✅ |

The browser never sends the `#fragment` to a server, so the key reaches only people who have the
link. The Canary tables have row-level security on and no grants to the public (`anon`) role; only
the edge function, using the service role, can read or write them.

## How each value is computed

| Value | Formula | Computed by |
|---|---|---|
| Chain note id | `0x` + sha256(`"nosus-canary:" + noteId`) | device and relayer |
| Copy digest | sha256(`salt + ":" + index + ":" + copyText`) with a random 32-byte salt kept on the device | device |
| Copies hash (sealed on chain) | `0x` + sha256(all copy digests joined in copy order) | device |
| Owner hash | sha256(`ownerSecret`), the secret is 32 random bytes kept on the device | device |
| Device hash | sha256(`"device:" + deviceId`) | relayer |
| Reader tag (on chain) | `0x` + sha256(`CANARY_TAG_SALT + ":" + noteId + ":" + copyIndex + ":" + deviceHash`) | relayer |

`CANARY_TAG_SALT` is a 32-byte server secret. Without it nobody can link a tag to a device or link
two tags from different notes. The memo format is specified in
[docs/RECEIPTS_SPEC.md](docs/RECEIPTS_SPEC.md).

## Threat model

**What Canary is for:** naming which reader's copy a leaked text came from, and keeping a neutral,
timestamped record of the seal and of each open.

| Who | What they try | What happens |
|---|---|---|
| A reader | Screenshot or copy-paste their copy | The copy is identified if enough text survives. See the measured rates below. |
| A reader | Strip invisible characters, change case or punctuation, OCR a screenshot | Still identified: the word swaps carry the fingerprint. |
| A reader | Retype the note in their own words | Can defeat it. Canary marks wording, not meaning. |
| Two readers | Blend their two copies | Usually names one of them; sometimes names an innocent reader (rates below). The app warns about this. |
| Anyone with the link | Open a copy and type a fake name | Works. A typed name is not an identity. The link is the access control: share it like a password. |
| Someone with the sender's device | Read the note, open the dashboard | Works. Device security is out of scope. |
| A passive observer of Solana | Learn the note, names or devices | Sees only hashes, copy counts, copy numbers, expiry and timestamps. |
| The server operator (us) | Read notes | Cannot: the server never has the key. |
| The server operator (us) | Give two readers the same copy, swap ciphertexts, or skip a receipt | Possible today. Partly detectable: the seal commits to every copy before anyone reads, and the sender's device can check any copy a reader shows them against it. Authenticated encryption (AES-GCM) is on the roadmap so a tampered copy fails to open. |
| Whoever steals the relayer key | Write fake memos from our relayer address | Possible. The key is a devnet key stored as a Supabase secret, never in the repo. Mainnet adds key rotation. |

**Measured leak matching** (`app/tool/canary_fingerprint_harness.dart`, run in CI; a note with 15
swappable words, like the app's demo note):

| Leak | 20 copies | 50 copies | 100 copies |
|---|---|---|---|
| Full copy without invisible marker, OCR-style text, 2% typos | 300 / 300 each, 0 wrong | 300 / 300 each, 0 wrong | 300 / 300 each, 0 wrong |
| Partial excerpts: named / wrong | 431 / 600, 0 wrong | 313 / 600, 0 wrong | 188 / 600, 0 wrong |
| Two copies blended: an innocent named | 1 / 600 | 8 / 600 | 23 / 600 |

## What we do not claim

- Canary does not stop screenshots. It makes them traceable.
- A receipt proves that the NO SUS relayer recorded an event at a time. It does not prove who a
  person is, that a human read the text, or who shared a leak.
- It is not legal evidence by itself.
- Deleting data from the server is an operational step, not something anyone can verify.

## Known gaps

- **Encryption mode.** Copies use AES-256 from `package:encrypt` with its default mode (SIC, which
  is CTR) and a random 16-byte IV per copy. There is no authentication tag. Planned: AES-GCM.
- **Relayer trust.** One relayer key signs every memo. Planned: several keys with rotation, and
  receipts batched under a Merkle root so a reader can check their own open.
- **Devnet only.** Devnet can be reset; receipts there are for demos, not records.

## Secrets in this repository

None. On 20 Oct 2026 every commit on every branch (46 commits, 17 refs, plus unreachable objects)
was scanned for Solana and EVM private keys, Supabase service-role and secret keys, GitHub, Google,
AWS, Stripe and AI-provider tokens, PEM keys and signing files. The only key-like value is the
Supabase **publishable** key in `app/lib/config/supabase_credentials.dart`, which is public by
design and gated by row-level security. Real secrets live only in Supabase function secrets and in
git-ignored files; see [.env.example](.env.example).
