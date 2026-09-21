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
