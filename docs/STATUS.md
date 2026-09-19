# Project status

## NO SUS Canary — 19 Sep 2026
- Feature: NO SUS Canary (server-gated copy delivery, client-side AES + local fingerprint matching)
- Contract NoSusCanary: Unit tests passing (5/5 NoSusCanary, 11/11 total). Deployment awaiting testnet wallet configuration.
- Migration `20260919090000_nosus_canary.sql` applied to ffidvfguojalzpclipzi: Yes (tables `canary_notes`, `canary_copies`, `canary_relayer_leases` verified with RLS active).
- Web app: Live at [http://shubham-sahu.me/nosus-canary/](http://shubham-sahu.me/nosus-canary/) (and [http://shubham-sahu.me/nosus-canary/#/canary](http://shubham-sahu.me/nosus-canary/#/canary)). Deployed standalone build (`NOSUS_CANARY_ONLY=true`): opens directly to NO SUS Canary landing page without workspace, login, or back arrow. Main NO SUS app has its login/auth gate restored (`AuthScreen`/`WelcomeScreen`), with Canary accessible without an account via `CanaryEntryCard`.
- HTTPS status: Custom domain `shubham-sahu.me` certificate pending in GitHub Pages; GitHub Pages origin `https://https-shubhamsahu.github.io/nosus-canary/` 301-redirects to `http://shubham-sahu.me/nosus-canary/`. Clipboard copy has browser fallback for HTTP.
- APK: Built `NO-SUS-Canary.apk` (34.4 MB, package `foo.nosus.canary`, `--target-platform android-arm64`, screen capture allowed for demo mirroring).
- Flutter app tests: 129 passed, 1 skipped, analyze 0 issues.

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
