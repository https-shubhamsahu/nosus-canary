# Project status

## NO SUS Canary × Solana — 10 Oct 2026 (in progress, worktree-solana-proof)
- **Owner decision (10 Oct 2026, later the same day): Monad is dropped.** Solana devnet is now the only receipt the product shows. The Monad code is kept behind switches so the earlier build can be reproduced:
  - Edge function: Monad runs only while the secret `CANARY_CONTRACT_ADDRESS` is set. Unset/empty = no viem calls, no relayer leases, `seal_tx_hash` / `open_tx_hash` stay `null`; `SOLANA_RELAYER_KEYS` is then required. With Monad off a failed Solana **seal** fails `create` with `retry: true`; a failed **open** memo is stored as `null` and resent on the next open of that copy. A note counts as sealed when `seal_tx_hash` **or** `seal_solana_sig` is set. Neither chain configured = 503. With both configured the behaviour is unchanged. Rules live in `app/supabase/functions/canary/gating.ts` (offline tests: `npx -y deno@2 test app/supabase/functions/canary/gating_test.ts`).
  - Flutter: build flag `CANARY_MONAD` (`kCanaryMonad` in `app/lib/config/app_mode.dart`, default `false`). Off = no wallet button/panel, no Monad chip, no "Verify on Monad", no Monad wording (tickers read "1 MEMO ON SOLANA DEVNET"). `--dart-define=CANARY_MONAD=true` restores the Monad UI as it was.
  - To turn Monad off on the server (owner approval): `supabase secrets unset --project-ref ffidvfguojalzpclipzi CANARY_CONTRACT_ADDRESS` after `SOLANA_RELAYER_KEYS` is set and funded.
- Goal (original): a second, parallel on-chain record for NO SUS Canary on **Solana devnet**, next to the existing Monad testnet one, for the Colosseum "Crypto World's Fair" hackathon submission (deadline 12 Oct 2026, 11:59 PM PT). Superseded by the decision above.
- Edge function `canary`: it already sends one Monad testnet transaction per note **seal** and per reader **open** (viem, leased relayer keys). With Solana configured it also sends **one Solana devnet transaction per seal and per open**, each carrying a single Memo-program instruction with a compact JSON memo: `{"p":"nosus-canary","v":1,"t":"seal",...}` for seals and `{"p":"nosus-canary","v":1,"t":"open",...}` for opens. The memo carries only the hashed ids already sent to Monad (chain note id, copies hash, copy index, salted reader tag). Never note text, keys, or names.
- While Monad is on, Solana is optional. With the secret `SOLANA_RELAYER_KEYS` unset the function behaves exactly as before. A Solana failure never fails a request while Monad is on: the signature is stored as `null` and retried on the next create/open call for that note/copy.
- Storage: migration `app/supabase/migrations/20261010090000_nosus_canary_solana.sql` adds nullable `canary_notes.seal_solana_sig` and `canary_copies.open_solana_sig`, and updates `canary_assign_copy` to also return `open_solana_sig`. Applied to `ffidvfguojalzpclipzi`: **Yes** (10 Oct 2026, via `supabase db query --linked --file`; columns and the 7-column function verified, anon still has no execute).
- New optional secrets (experiment project `ffidvfguojalzpclipzi` only; never production `rxfnazmusofikwaggntb`):
  - `SOLANA_RELAYER_KEYS` — comma-separated devnet relayer secret keys, each a base58 64-byte secret key or a `solana-keygen` JSON array. Devnet only.
  - `SOLANA_RPC_URL` — default `https://api.devnet.solana.com`.
  - `SOLANA_MEMO_PROGRAM` — default legacy Memo v2 `MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr`.
- API: create / open / status responses add `seal_solana_sig` / `open_solana_sig` (`string | null`) next to the existing `seal_tx_hash` / `open_tx_hash`.
- Flutter app: a **Solana** proof chip linking to `https://explorer.solana.com/tx/<sig>?cluster=devnet` (shown whenever a signature exists). In a `CANARY_MONAD=true` build it sits next to the Monad chip and the tickers say "1 TX ON MONAD + 1 ON SOLANA". Records saved before this change have no Solana signature and show no Solana chip.
- Spike: `tool/solana-spike/send_memo.ts` (Deno) exercises the production Solana module against devnet.
- Deployed: **Yes** (10 Oct 2026). `SOLANA_RELAYER_KEYS` + `SOLANA_RPC_URL` set, `CANARY_CONTRACT_ADDRESS` unset (Monad off), function `canary` deployed, Solana-only web build live at http://shubham-sahu.me/nosus-canary/ (gh-pages `5cbac10`).
  - The function is deployed **pre-bundled** (`deno bundle --platform=deno` → one file, `--use-api`): Supabase's server-side bundler timed out twice on `npm:@solana/kit`. Bundle and deploy from a scratch workdir; the repo source is unchanged.
  - Fix found on the live run: the edge runtime resolves `@solana/kit`'s Node build, whose base64 codec reads the global `Buffer` (`ReferenceError: Buffer is not defined`). `solana.ts` now sets `globalThis.Buffer` from `node:buffer`.
- Evidence so far:
  - First devnet seal signature (spike, 10 Oct 2026): [`2BHqnu…`](https://explorer.solana.com/tx/2BHqnuCxYyemfegHkncgTsQyMPjpyB9boD1XqYfD1Wtbcf51Fpy3y264UwGhnvRKtcxFKCaSAzHxLrDwFRk512bQ?cluster=devnet); open: [`NwoJau…`](https://explorer.solana.com/tx/NwoJauec9otkicaGf8yD6UechYgUnXRdYPqnuc5Kpn6uMYym6XVJcMmWdbVnwnRVncKKVgEyuZB2mR3T5REvdSr?cluster=devnet). Confirmed in ~1.1 s each, 91,585 CU, fee 5,000 lamports, memo round trip OK. Relayer `CCD4SUQt4No2QNidpCuNAxJZXsqY1KhxkpfkuphueQJx` funded with 5 devnet SOL from faucet.solana.com.
  - Live end-to-end (10 Oct 2026, scripted Chrome at 1920×1080 against the live site): create (10 copies) → sealed on Solana; two readers opened copies 1 and 2, each open recorded on Solana; dashboard showed both with Solana proof chips; Check a leak on reader 1's text → "The canary sang · Priya · copy 1 / 10"; the proof chip opened the memo on Solana Explorer (one Memo instruction, hashes only).
  - Offline logic test of `solana.ts` (scratch, imports the production module): 6/6 passed — base58 + JSON-array key parsing, defaults, p-memo override, bad-config rejection without echoing key material, derived signer address, byte-exact memo JSON.
  - Packages pinned: `npm:@solana/kit@8.4.0`, `npm:@solana-program/memo@0.15.0`; transactions are v0 (verifiers pass `maxSupportedTransactionVersion: 0`); memo payload ≤ 219 bytes.
  - Edge function `npx -y deno@2 check index.ts`: `clean — exit 0 (Deno 2.9.6 via `npx -y deno`; the esm.sh supabase-js types raised no complaints; `tool/solana-spike/send_memo.ts` also checks clean)`
  - `flutter analyze` / `flutter test`: `flutter analyze`: No issues found · `flutter test`: 145 passed, 1 skipped (unit 76 incl. 7 new in canary_link_test + canary_models_test; widget 26 incl. 5 new in proof_chips_test)
  - After dropping Monad (default build, `CANARY_MONAD` off): `flutter analyze` no issues · `flutter test` 153 passed, 1 skipped. Canary tests also pass with `--dart-define=CANARY_MONAD=true`. `deno check index.ts` clean; `gating_test.ts` 7/7 passed.
- Deploy runbook (owner approval required for every step):
  1. Generate a devnet keypair locally (for example `solana-keygen new --outfile <git-ignored path>.json`). Keys stay in git-ignored files or PowerShell variables; never paste keys in chat, commits, or logs.
  2. Fund it with devnet SOL at https://faucet.solana.com (devnet only, no value).
  3. `supabase secrets set --project-ref ffidvfguojalzpclipzi SOLANA_RELAYER_KEYS=… SOLANA_RPC_URL=https://api.devnet.solana.com` (read the key from a PowerShell variable; set `SOLANA_MEMO_PROGRAM` only if the default must change).
  4. Apply the migration: `supabase db query --linked --file app/supabase/migrations/20261010090000_nosus_canary_solana.sql`. **Never `supabase db push`**: build-plan rule 5 records that the remote migration history holds only the bootstrap entry, so `db push` would try to re-apply ~21 old migrations and break the database.
  5. `supabase functions deploy canary --project-ref ffidvfguojalzpclipzi --no-verify-jwt --use-api` (same flags as the build plan; without `--no-verify-jwt` the function returns 401).
  6. Rebuild the web app: from `app/`, in PowerShell, `flutter build web --release --base-href /nosus-canary/ --dart-define=NOSUS_CANARY_ONLY=true` (Monad hidden by default; add `--dart-define=CANARY_MONAD=true` only to reproduce the Monad build); copy `build/web/.` into the root of `gh-pages` (keep `hub/` and the `app/` redirect), then commit and push (see the 22 Sep hosting note below).
  7. Verify: create a Canary link, open a copy in a private window, and click the **Solana** chip. It must open `https://explorer.solana.com/tx/<sig>?cluster=devnet` showing one Memo instruction whose JSON starts `{"p":"nosus-canary","v":1,"t":"open"` and contains hashes only. Record the seal signature in "Evidence so far" and in `docs/canary/VERIFICATION.md`.

## NO SUS Canary — 19 Sep 2026
- Feature: NO SUS Canary (server-gated copy delivery, client-side AES + local fingerprint matching)
- Contract NoSusCanary: Deployed at `0xb1a1858866122c84cf97861ca815fb070e010e68` on Monad Testnet (Chain ID 10143). Verified on Sourcify / Monadscan. 10 relayers funded (0.5 MON each) and authorized.
- Edge function `canary`: Deployed to project `ffidvfguojalzpclipzi` with secrets set (`CANARY_CONTRACT_ADDRESS`, `CANARY_RELAYER_KEYS`, `CANARY_TAG_SALT`, `MONAD_RPC_URL`). Smoke test verified.
- Migration `20260919090000_nosus_canary.sql` applied to ffidvfguojalzpclipzi: Yes (tables `canary_notes`, `canary_copies`, `canary_relayer_leases` verified with RLS active).
- Web app: Live at [http://shubham-sahu.me/nosus-canary/](http://shubham-sahu.me/nosus-canary/) (and [http://shubham-sahu.me/nosus-canary/#/canary](http://shubham-sahu.me/nosus-canary/#/canary)). Deployed standalone build (`NOSUS_CANARY_ONLY=true`) with the signature NO SUS black and white monochrome theme (`NoSusTheme`): opens directly to NO SUS Canary landing page without workspace, login, or back arrow, with a "NO SUS app ↗" link to `https://nosus.foo`. Main NO SUS app has its login/auth gate restored (`AuthScreen`/`WelcomeScreen`), with Canary accessible without an account via `CanaryEntryCard`.
- HTTPS status: Custom domain `shubham-sahu.me` certificate pending in GitHub Pages; GitHub Pages origin `https://https-shubhamsahu.github.io/nosus-canary/` 301-redirects to `http://shubham-sahu.me/nosus-canary/`. Clipboard copy has browser fallback for HTTP.
- APK: Built `NO-SUS-Canary.apk` (34.4 MB, package `foo.nosus.canary`, `--target-platform android-arm64`, screen capture allowed for demo mirroring).
- Flutter app tests: 129 passed, 1 skipped, analyze 0 issues.
- Hardening pass (22 Sep 2026, local only, not deployed):
  - Codeword generation is about 4× faster, with byte-identical output.
  - Dashboard polling stops once every copy is opened or the link expires.
  - Errors from async work after a screen closes are guarded, and raw exception text is no longer shown to users.
  - The Verify-on-Monad RPC has a 15 s timeout.
  - `docs/canary/reference/` was removed after being merged. The fingerprint harness is now `app/tool/canary_fingerprint_harness.dart` (FAILURES: 0).
  - Checks: 133 passed, 1 skipped; analyze 0 issues.
- Hosting (22 Sep 2026): this repo, renamed from `nosus-monad` (old URLs redirect), now also hosts the site. Source is on `main`; the built site is on `gh-pages` and served at http://shubham-sahu.me/nosus-canary/ (`app/` = the Flutter build, `hub/` + `index.html` = landing).
  - To deploy: from `app/`, run `flutter build web --release --base-href /nosus-canary/ --dart-define=NOSUS_CANARY_ONLY=true` in PowerShell, copy `build/web/.` into the root of `gh-pages` (keep `hub/` and the `app/` redirect), then commit and push. Since 10 Oct 2026 the app is served at https://shubham-sahu.me/nosus-canary/; `/app/` redirects there keeping the hash, so older reader links still open.
  - The separate site repo was retired.

## Current state


Repository scaffolded on 16 September 2026. Gate T1 is **not** verified. Nothing is
deployed, no Supabase project is linked, and the product latch in
`web/src/lib/threshold.ts` remains `spike-required`.

## Completed locally

- `NoSusMonadDrops` records a digest, optional recipient, expiry, sender, and exactly one opener.
  It has no owner, payment, key, salt, or plaintext path. `canDecrypt` is false before
  acknowledgement, false for any non-opener, and false after expiry even if already opened.
- Contract tests: `6 passing (6 nodejs)` from `contracts/npm test`, including zero-address
  denial and the exact-expiry boundary.
- The Next.js experience includes a restrained, flat black-and-white sender view, recipient acknowledgement route,
  verifier, and backend-powered-but-empty Receipt Wall. It refuses to create or decrypt a drop
  until Gate T1 is verified. The verifier can read `receiptOf` / `canDecrypt` from Monad when a
  contract address is configured; that is a public view, not a Lit unlock.
- Lit SDK selection: `@lit-protocol/lit-client` **8.3.1**, `@lit-protocol/networks` **8.4.1**,
  and `@lit-protocol/auth` **8.2.3** on **naga-dev**. Retired Datil/`lit-node-client` packages
  are not direct dependencies. Nested packages still print retirement warnings at install time.
- The access-control condition uses Lit chain key `monadTestnet` (in
  `@lit-protocol/accs-schemas`, chain ID 10143) and `canDecrypt(id, :userAddress)`.
- Gate T1 runner: `tool/threshold-spike` now prepares the sender, recipient, and stranger proof:
  recipient denial before acknowledgement, sender seal, recipient acknowledgement and decrypt,
  stranger denial, and an optional expiry denial. `npm run check` → 2 passing and `npm run dry-run`
  passed. It has not connected to Lit or Monad, and no live wallet/decrypt result has been recorded.
- Web check: `web/npm run check` passed.
- Local visual review passed at `http://127.0.0.1:3017`. The UI uses local Geist assets and the
  documented three-layer token system; production Burn components were not imported.
- Navigation check: `node tool/check-repository.mjs` passed.
- Initial isolated Supabase migration was created locally only; it has not been applied anywhere.
- Testnet deploys require `CONFIRM_MONAD_DEPLOY=1` after an explicit named-target approval.

## Next blocking milestone

Prove the threshold gate on Monad testnet using two wallets:

1. An unopened wallet cannot decrypt.
2. The acknowledged wallet can decrypt.
3. A second wallet cannot decrypt.
4. An expired or already-opened drop cannot decrypt.

Do not build demo claims, real drop creation, public deployment, or substitute a server gate ahead
of this result. See `LIT_MONAD_SPIKE.md` for the exact evidence to collect. The user must still
name a Monad Testnet deployment target and provide two controlled test wallets before a live run.

## Deliberate decisions

- Display brand: **NO SUS — Monad Experiment**.
- Separate repository and backend; no future production integration is implied.
- Open wallet connect is the primary demo flow; keep a prepared test wallet as an operator fallback.
- Demo material is limited to harmless personal test notes.
- Lit Protocol is the selected threshold-custody provider. Its Monad evaluation is a technical gate,
  not an assumption. The `monadTestnet` ACC chain key is the identifier to try; a live decrypt
  result is the only accepted proof.
- Datil / `@lit-protocol/lit-node-client` is retired (sunset 25 February 2026) and is not used.
