# How NO SUS Canary was verified (19 Sep 2026)

The reference sources this log describes were merged into `app/` and `contracts/`, and the
`docs/canary/reference/` copies were removed on 22 Sep 2026. The fingerprint harness now lives at
`app/tool/canary_fingerprint_harness.dart`: run `dart run tool/canary_fingerprint_harness.dart` from
`app/` after changing the word list; it must end with `FAILURES: 0`.

All checks ran on the owner's machine, in a scratch copy of `nosus-monad/app` (the real repo was
not modified). The steps were: copy `app/`, copy the reference files in, run
`tools/canary_edits.js` once, run `flutter pub add qr_flutter image_picker google_mlkit_text_recognition`,
then run the checks below.

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found** |
| Full Flutter test suite (existing + 2 new Canary files) | `flutter test` | **All tests passed** (129 passed, 1 skipped) |
| Web release build | `flutter build web --release --base-href /nosus-canary/` (PowerShell) | **OK**. `<base href="/nosus-canary/">`; `build/web/CNAME` present → must be deleted before Pages |
| Android release APK | `flutter build apk --release --target-platform android-arm64 --dart-define=WEB_APP_ORIGIN=https://https-shubhamsahu.github.io --dart-define=WEB_APP_BASE_PATH=/nosus-canary --dart-define=NOSUS_ALLOW_SCREEN_CAPTURE=true` (PowerShell) | **Built app-release.apk (34.4 MB)**. `aapt`: package `foo.nosus.canary`, label `NO SUS`, minSdk 24. The first attempt failed in R8 until the ML Kit `-dontwarn` rules were added (now part of `canary_edits.js`) |
| Edit script | `node tools/canary_edits.js` on fresh copies of the 11 target files | `ALL EDITS APPLIED` (tested twice from pristine files) |
| Contract | `npx hardhat test` (Hardhat 3, viem) | **5 passing** for NoSusCanary. Gas: `sealNote` 73,833, `openCopy` 78,403 |
| Edge function | `npx -y deno@2 check index.ts` | **OK**. Resolves `npm:viem@2.56.5` and `esm.sh supabase-js@2.39.8` |
| Fingerprint engine | `dart run tool/canary_fingerprint_harness.dart` (from `app/`) | **FAILURES: 0**. With the 15-slot demo note: full, stripped and OCR-style copies 300/300; 2% character noise 300/300 with 0 wrong names; excerpts 0 wrong out of 600; two-copy blends named an innocent in 1/600 (20 copies), 8/600 (50) and 23/600 (100). A 9-slot note is rejected on purpose |

**Not verified here** (these need owner-approved live services, so they are done in the plan's
Phases 2–7): deploying to Monad testnet, applying the SQL to `ffidvfguojalzpclipzi`, deploying the
edge function, and the live end-to-end flow. The SQL and the edge-function logic were reviewed but
not executed against a database.

---

# NO SUS Canary × Solana devnet memo log (10 Oct 2026, in progress)

Branch `worktree-solana-proof`. Scope: the edge function `canary` writes one Solana devnet
Memo-program transaction per note seal and per reader open, in parallel with the existing Monad
testnet transaction; new nullable columns `canary_notes.seal_solana_sig` and
`canary_copies.open_solana_sig` (migration `20261010090000_nosus_canary_solana.sql`, which also makes
`canary_assign_copy` return `open_solana_sig`); optional secrets `SOLANA_RELAYER_KEYS`,
`SOLANA_RPC_URL`, `SOLANA_MEMO_PROGRAM`; a second "Solana" proof chip in the Flutter app. The memo
carries only the hashed ids already sent to Monad. Solana is optional and a Solana failure never
fails a request.

Replace every `<PENDING: …>` cell with the real output. Until then nothing below counts as verified.

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` (from `app/`) | `flutter analyze`: No issues found · `flutter test`: 145 passed, 1 skipped (unit 76 incl. 7 new in canary_link_test + canary_models_test; widget 26 incl. 5 new in proof_chips_test) |
| Full Flutter test suite | `flutter test` (from `app/`) | `flutter analyze`: No issues found · `flutter test`: 145 passed, 1 skipped (unit 76 incl. 7 new in canary_link_test + canary_models_test; widget 26 incl. 5 new in proof_chips_test) |
| Edge function type-check | `npx -y deno@2 check index.ts` (from `app/supabase/functions/canary/`) | `clean — exit 0 (Deno 2.9.6 via `npx -y deno`; the esm.sh supabase-js types raised no complaints; `tool/solana-spike/send_memo.ts` also checks clean)` |
| Solana spike against devnet | `tool/solana-spike/send_memo.ts` with Deno, as described in its header comment; needs a funded devnet key in a git-ignored env file | Seal [`2BHqnuCx…`](https://explorer.solana.com/tx/2BHqnuCxYyemfegHkncgTsQyMPjpyB9boD1XqYfD1Wtbcf51Fpy3y264UwGhnvRKtcxFKCaSAzHxLrDwFRk512bQ?cluster=devnet), open [`NwoJauec…`](https://explorer.solana.com/tx/NwoJauec9otkicaGf8yD6UechYgUnXRdYPqnuc5Kpn6uMYym6XVJcMmWdbVnwnRVncKKVgEyuZB2mR3T5REvdSr?cluster=devnet); round trip OK (10 Oct 2026) |
| Solana off = unchanged behaviour | Create + open with `SOLANA_RELAYER_KEYS` unset; responses must still carry `seal_tx_hash` / `open_tx_hash` and `seal_solana_sig: null` / `open_solana_sig: null` | Not run — superseded: Monad was turned off instead (10 Oct 2026) and Solana is now the only receipt; gating covered offline by `gating_test.ts` (7/7) |
| Memo content | Open the recorded signature at `https://explorer.solana.com/tx/<sig>?cluster=devnet`; exactly one Memo instruction, JSON `{"p":"nosus-canary","v":1,"t":"seal"…}` or `"t":"open"`, hashes only (no text, keys, names) | One Memo instruction; JSON `{"p":"nosus-canary","v":1,"t":"seal","note":"0x…","copies":10,"hash":"0x…","exp":…}` — hashes only (checked on Solana Explorer, 10 Oct 2026) |
| Migration on `ffidvfguojalzpclipzi` [OWNER APPROVAL] | `supabase db query --linked --file app/supabase/migrations/20261010090000_nosus_canary_solana.sql` (never `supabase db push`) | Applied 10 Oct 2026; columns + 7-column `canary_assign_copy` verified, anon has no execute |
| Live end-to-end [OWNER APPROVAL] | Deploy the function, create a link, open a copy, click the **Solana** chip | Passed 10 Oct 2026 on the live site: create → 2 opens → dashboard chips → leak check named copy 1 → explorer memo |

**Not verified here** until the owner approves the live steps: funding a devnet key, setting
secrets, applying the SQL to `ffidvfguojalzpclipzi`, deploying the function, and the live flow.
Production project `rxfnazmusofikwaggntb` is never used.
