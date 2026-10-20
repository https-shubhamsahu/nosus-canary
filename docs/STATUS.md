# Status (20 Oct 2026)

## Live

- **Web app:** https://shubham-sahu.me/nosus-canary/ (gh-pages, standalone build
  `NOSUS_CANARY_ONLY=true`, base href `/nosus-canary/`). `/nosus-canary/app/` redirects there and
  keeps the hash, so older reader links still open.
- **Backend:** Supabase project `ffidvfguojalzpclipzi` (experiment project only; never the NO SUS
  production project). It was paused for inactivity and restored on 20 Oct 2026.
- **Relayer:** edge function `canary`, version 7, deployed 20 Oct 2026 from `chore/judge-ready`
  (pre-bundled with `deno bundle`, steps in [SELF_HOSTING.md](SELF_HOSTING.md)). It runs
  `packages/receipts-ts`. Version 6 (10 Oct) was downloaded as a backup before the deploy.
  Secrets set: `CANARY_TAG_SALT`, `SOLANA_RELAYER_KEYS`, `SOLANA_RPC_URL`. `CANARY_CONTRACT_ADDRESS`
  is unset, which keeps the legacy EVM prototype path off.
- **Receipts:** Solana devnet, relayer `CCD4SUQt4No2QNidpCuNAxJZXsqY1KhxkpfkuphueQJx`. 31 receipts
  (19 seals, 12 opens, 0 failed) as of 20 Oct 2026.

## Changed on 20 Oct 2026

- `packages/receipts-ts` and `packages/receipts-dart` (v0.1) and shared test vectors. The relayer's
  `solana.ts` imports `packages/receipts-ts`; memo bytes are unchanged (checked against the real
  devnet memos in `solana_test.ts`) and the deployed relayer was smoke-tested on devnet.
- Pitch and demo videos are attached to the `v0.1.0` GitHub release.
- Dead prototype code removed: the Solidity contracts, the Next.js threshold-decrypt spike and its
  docs. History keeps them (last on `main` at `f1bb47e`).
- CI now runs Flutter analyze and tests, the fingerprint harness, Deno checks and tests for the
  relayer and the TS library, and Dart checks and tests for the Dart library.

## Owner approval needed for

Deploying the function, applying SQL, setting secrets, funding keys or spending devnet SOL,
changing gh-pages, merging, pushing, and anything made public.

## Rules worth repeating

- Never run `supabase db push` against `ffidvfguojalzpclipzi`: its remote migration history holds
  only the bootstrap entry, so `db push` would try to re-apply old migrations. Apply single files
  with `supabase db query --linked --file …`.
- Deploy `canary` with `--no-verify-jwt`; callers send only the publishable key.
- Keep `CANARY_MONAD` (Flutter) off and `CANARY_CONTRACT_ADDRESS` (function) unset.
- Use harmless test notes only.

## Next

See the roadmap in the [README](../README.md#roadmap): mainnet, publishing the receipts library,
the Android app on the Solana dApp Store, PDFs and images, batched receipts, AES-GCM.
