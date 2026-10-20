# Verification log

Every check below was run on the owner's machine. "Live" rows touched the real devnet backend with
owner approval.

## 20 Oct 2026 (branch `chore/judge-ready`)

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` (from `app/`) | No issues found |
| Flutter tests | `flutter test` (from `app/`) | All passed (live-network diagnostic `db_test.dart` removed; `supabase_service_test.dart` stays skipped) |
| Fingerprint harness | `dart run tool/canary_fingerprint_harness.dart` (from `app/`) | `FAILURES: 0` |
| Relayer type-check | `deno check index.ts` (from `app/supabase/functions/canary/`) | Clean |
| Relayer tests | `deno test --allow-env` (same folder) | `gating_test.ts` 7 passed, `solana_test.ts` 5 passed |
| Relayer bundle | `deno bundle --platform=deno app/supabase/functions/canary/index.ts -o <scratch>/index.ts` | OK, 2.3 MB |
| TS library | `deno check`, `deno lint`, `deno fmt --check`, `deno test` (from `packages/receipts-ts/`) | All clean, 19 passed |
| Dart library | `dart analyze`, `dart format --set-exit-if-changed .`, `dart test` (from `packages/receipts-dart/`) | No issues, 16 passed |
| Secret scan | All 46 commits on 17 refs plus unreachable objects | No secrets; only the Supabase publishable key (public by design) |
| Live end to end | Scripted Chrome on https://shubham-sahu.me/nosus-canary/ at 1280×720: create (10 copies, 1 hour) → Priya and Ben open → dashboard → leak check → Explorer | Sealed in 2.9 s; leak check named "Priya · Copy 1 / 10"; receipts below |

Receipts from the live run:
[seal](https://explorer.solana.com/tx/QqdiqT84UfFyHNhpfLrK32HfqbUB5vF8qtC4DiAQ7wZZGn2MkUVJGGpVPpgmk4MCxVLtkhmZm6rbuBxqyuL11wb?cluster=devnet),
[Priya's open](https://explorer.solana.com/tx/5TXFPfTDFWyVe98DVPph7r55uRdJAcih6vKMBBRJKA96KtWT7Q4MUoFQG6GwH8N1FFkiMMbZzPssGtqtoW3wAsy2?cluster=devnet),
[Ben's open](https://explorer.solana.com/tx/3tqhYUQ2BppvWh6dy8q5u7U23NpZ7FqfAnd34B58GTriGVZXtykcPj1i4sF7bNh4t8ShnhQokySNz7Uwh7GMTcT1?cluster=devnet).
Two earlier attempts the same day sealed a note each (one also recorded one open) before the
recording script failed; those three memos are harmless test data.

## 10 Oct 2026 (Solana receipts)

| Check | Result |
|---|---|
| Spike against devnet (`tool/solana-spike/send_memo.ts`) | Seal [`2BHqnuCx…`](https://explorer.solana.com/tx/2BHqnuCxYyemfegHkncgTsQyMPjpyB9boD1XqYfD1Wtbcf51Fpy3y264UwGhnvRKtcxFKCaSAzHxLrDwFRk512bQ?cluster=devnet) and open [`NwoJauec…`](https://explorer.solana.com/tx/NwoJauec9otkicaGf8yD6UechYgUnXRdYPqnuc5Kpn6uMYym6XVJcMmWdbVnwnRVncKKVgEyuZB2mR3T5REvdSr?cluster=devnet), ~1.1 s each, 5,000 lamports, memo round trip OK |
| Migration `20261010090000_nosus_canary_solana.sql` on `ffidvfguojalzpclipzi` | Applied with `supabase db query --linked --file`; columns and the 7-column `canary_assign_copy` verified; `anon` has no execute |
| Live end to end | Create (10 copies) → 2 opens → dashboard chips → leak check named copy 1 → Explorer memo with hashes only |
| `flutter analyze` / `flutter test` | No issues / 153 passed, 1 skipped |
| `deno check index.ts` / `gating_test.ts` | Clean / 7 passed |

## 19–22 Sep 2026 (Canary feature)

| Check | Result |
|---|---|
| Fingerprint harness | `FAILURES: 0` (see the table in [SECURITY.md](../../SECURITY.md#threat-model)) |
| Web release build | `flutter build web --release --base-href /nosus-canary/` OK |
| Android release APK | Built (34.4 MB, package `foo.nosus.canary`, minSdk 24) |
