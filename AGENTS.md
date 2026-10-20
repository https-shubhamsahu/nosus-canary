# NO SUS Canary: agent map

Read [docs/STATUS.md](docs/STATUS.md) first, then only the guide for the files you will change.

## What this is

NO SUS Canary: every reader of a note gets a uniquely marked copy, and every seal and every open is
one SPL Memo transaction on **Solana devnet**, sent by a relayer (Supabase Edge Function `canary`)
so readers need no wallet. Leak matching runs on the sender's device.

## Map

| Area | Code | Read first |
|---|---|---|
| Canary UI and fingerprinting | `app/lib/features/canary/` | `app/AGENTS.md` |
| Relayer | `app/supabase/functions/canary/` | `docs/ARCHITECTURE.md` |
| Receipt format and libraries | `packages/receipts-ts/`, `packages/receipts-dart/`, `packages/test-vectors/` | `docs/RECEIPTS_SPEC.md` |
| Schema | `app/supabase/migrations/2026091909*`, `2026101009*` | `docs/SELF_HOSTING.md` |
| Security model | — | `SECURITY.md` |

## Rules

- Backend: experiment project `ffidvfguojalzpclipzi` only. Never touch the NO SUS production
  project, its credentials or deployment.
- Never put note text, keys, names or device ids on chain. Memos carry hashes only; the format is
  frozen at v1 (see the spec) and both libraries must stay byte-identical with the test vectors.
- Secrets live in Supabase function secrets or git-ignored files (`.env.example` lists them). The
  Supabase publishable key in `app/lib/config/supabase_credentials.dart` is public by design.
- Keep the legacy EVM prototype path off: `CANARY_MONAD` stays false in Flutter and
  `CANARY_CONTRACT_ADDRESS` stays unset for the function. User-facing text mentions Solana only.
- Never claim screenshot prevention, legal proof, identity proof or proof that a human read a note.
- Use harmless test notes only.
- Smallest change that works. No new dependency or abstraction without a current consumer.
- Owner approval is needed every time for: commits and pushes, merges, deploying the function,
  applying SQL, setting secrets, funding keys or spending devnet SOL, changing gh-pages, and
  making anything public.

## Checks (CI runs all of these)

```bash
(cd app && flutter analyze && flutter test && dart run tool/canary_fingerprint_harness.dart)
(cd app/supabase/functions/canary && deno check index.ts && deno test --allow-env)
(cd packages/receipts-ts && deno check mod.ts cli.ts && deno lint && deno fmt --check && deno test)
(cd packages/receipts-dart && dart pub get && dart analyze && dart format --set-exit-if-changed . && dart test)
```
