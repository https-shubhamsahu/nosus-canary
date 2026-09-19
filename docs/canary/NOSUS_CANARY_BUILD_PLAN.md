# NO SUS Canary — build plan for the Flutter app (Android APK + web)

Owner decision (19 Sep 2026): the product is called **NO SUS**. The feature is **NO SUS Canary**.
This plan lets any AI agent, including a less capable one, build and ship it without guessing.
Every piece of code it needs is already written, and has been compiled, analyzed and tested on
this exact machine. It is stored in [`reference/`](reference/). Your job is mostly to **copy
files, run commands and check results**. Do not rewrite the reference code.

---

## 0. Read this first (rules for any agent)

1. **Work top to bottom.** Every step ends with a **DONE WHEN** check. Do not start the next step
   until that check passes. After each step, tick it in the Progress log (section 9).
2. **Copy, don't retype.** Take source files from `docs/canary/reference/` with the copy commands
   given here. Retyping code from this document is how mistakes happen.
3. **Owner approval gates.** Steps marked **[OWNER APPROVAL]** touch real services (Monad testnet
   funds, the Supabase database, secrets, public GitHub). Ask the owner, in plain words, before
   running them, and wait for a clear "yes" to that exact step. A "yes" to one step does not cover
   the next one.
4. **Never touch production.** The production Supabase project is `rxfnazmusofikwaggntb`: never
   use it. The only backend is the experiment project `ffidvfguojalzpclipzi`. The production app
   id is `foo.nosus.app`; this build uses `foo.nosus.canary`.
5. **NEVER run `supabase db push`.** The remote migration history holds only one entry, for the
   bootstrap. `db push` would try to re-apply ~21 old migrations and break the database. Apply the
   one new SQL file with `supabase db query --linked --file …` (Phase 3).
6. **Secrets never go in chat, commits, logs, or `--dart-define`.** Keys stay in git-ignored
   files, or in PowerShell variables that are never printed.
7. **Use PowerShell for every `flutter build` and `gh api` command.** Git Bash rewrites arguments
   that start with `/`: it turned `--base-href /nosus-canary/` into
   `C:/Program Files/Git/nosus-canary/`, and the build failed. If you must use Git Bash, prefix
   the command with `MSYS_NO_PATHCONV=1`.
8. **Line endings.** Most files in `app/` use CRLF, and some lines added later use LF. The
   reference edit script handles both. If you edit by hand and an exact-text match fails, line
   endings are the likely cause.
9. **Stop and ask the owner if** any DONE WHEN check fails twice, if a step needs a production
   credential, or if something in this plan contradicts what you see on disk.
10. `nosus-monad/AGENTS.md` asks you to end every response that changed files with its
    finalization question. Keep doing that.

**Flutter SDK:** `C:\Users\shubh\AppData\Local\flutter\bin\flutter.bat` (Flutter 3.44.4, Dart 3.12.2).
This document writes Flutter commands as `FLUTTER <args>`. **At the start of every new PowerShell
session**, run this once so those commands work exactly as written:
```powershell
Set-Alias FLUTTER "C:\Users\shubh\AppData\Local\flutter\bin\flutter.bat"
```

---

## 1. What we are building

**One line:** *Every reader gets their own copy. If it leaks, see whose copy it was.*

### Flows

| Who | What they do | What happens |
|---|---|---|
| **Sender** (APK or web, no account needed) | Welcome or Workspace → **NO SUS Canary** → **New Canary note** → types the note (or taps **Use the demo note**) → chooses the number of readers (10/20/50/100) and the expiry (1 h/1 day/7 days) → **Create Canary link** | The phone builds N copies that differ only in small word choices (e.g. "don't"/"do not", "organize"/"organise", "five"/"5"), plus an invisible marker. It encrypts each copy with one AES key and uploads **only ciphertext**. The key stays in the link's `#` fragment. Monad testnet records a hash committing to all copies (`sealNote`). The sender gets one link, a QR code and a "See the magic" view. |
| **Reader** (any phone browser, no install) | Opens the link → types their name → **Open my copy** | The server gives this device the next unused copy (the same copy again on refresh). Monad records "copy #i was opened" with an anonymous tag (`openCopy`). The phone decrypts and shows **"Copy 7 of 50 · made for Priya"** plus a proof link. |
| **Sender** | Note dashboard → **Seen by** list (updates every 3 s) → **Check a leak** → paste the leaked text (or, on Android, **Read a screenshot**) | Matching runs **on the sender's device**: "🐤 The canary sang. Copy #7 — Priya", with the open time and a Monad proof link. |

### Honesty rules (they are already in the UI copy; keep them)
- Canary shows **whose copy** leaked, not **who shared it**. It never claims to block screenshots.
- If two readers compare and mix their copies, the result can point at the wrong copy. The matcher
  is deliberately strict and names nobody when no single copy fits.
- The server hands out encrypted copies (it decides which reader gets which copy) and cannot read
  them. This is **not** threshold custody (Lit/Gate T1). Canary does not change Gate T1 or
  `monadThresholdVerified`.
- Monad testnet receives only hashes and anonymous tags, never text or names.

---

## 2. Verified facts about this machine and repo (checked 19 Sep 2026)

| Fact | Value / consequence |
|---|---|
| Repo | `C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad`, branch `codex/flutter-monad-integration`, with uncommitted changes. **`app/` is untracked** (never committed). |
| Flutter app | `nosus-monad/app` (package `no_sus`), Riverpod 3, Supabase, `encrypt` (the same AES used by Burn Notes). Baseline `flutter analyze`: **no issues**. |
| Tools | Node 22.17.0, npm 11.5.2, Supabase CLI 2.105.0 (logged in, `app/supabase` linked to `ffidvfguojalzpclipzi`), Docker 29.6.2, gh 2.95 (logged in as **https-shubhamsahu**), Vercel CLI 50.25.4, Java 17, adb at `C:\Users\shubh\AppData\Local\Android\Sdk\platform-tools\adb.exe` |
| Experiment backend | Live: `burn_notes` and `remote_configs` exist, and the function `create-redemption-code` is deployed. **Remote migration history = only `20260917205606`** (hence rule 5). |
| Monad RPC | `https://testnet-rpc.monad.xyz` **works** (chain 10143, gas price ≈ 102 gwei). `https://rpc.testnet.monad.xyz`, the default in `contracts/hardhat.config.ts`, **does not respond**, so always set `MONAD_RPC_URL`. |
| Explorer | `https://testnet.monadscan.com/tx/<hash>` responds. The app uses it. |
| Web hosting | `monad.nosus.foo` is **not live**. Production `app.nosus.foo` is on GitHub Pages. Canary web goes to **GitHub Pages: `https://https-shubhamsahu.github.io/nosus-canary/`**. |
| `web/CNAME` | Contains `monad.nosus.foo` and is copied into `build/web`. It **must be deleted** before publishing to GitHub Pages, or Pages tries to use that dead domain. |
| Android identity | The copied app used production `applicationId "foo.nosus.app"`. This plan changes it to **`foo.nosus.canary`**, which avoids the signature-conflict error "App not installed" and keeps it off the production Play identity. `namespace` stays `foo.nosus.app` because the Kotlin sources live in that package. |
| Screen capture | `MainActivity.onCreate` sets `FLAG_SECURE`, and so does `ScreenshotGuard.initialize()` (screenshots and mirroring show black). A demo build passes `NOSUS_ALLOW_SCREEN_CAPTURE=true`, which calls the existing `disableSecure` channel. |
| APK build time | About 10 minutes for a full release build. Use `--target-platform android-arm64` for a faster, smaller APK. Do not run other heavy jobs at the same time: one attempt died with "Could not start thread DartWorker" while another job was running. |
| Contract gas (measured) | `sealNote` 73,833 and `openCopy` 78,403. The limit used is **150,000**. Monad charges the gas **limit**, so each write costs about **0.0153 MON** at 102 gwei. |
| Fingerprint accuracy (measured, 20–100 copies, 15-slot demo note) | Full copy, marker stripped, OCR-style text: **300/300** correct. 2% character noise: 300/300 correct, **0 wrong names**. Partial excerpts: **0 wrong names** out of 600. Two copies mixed together: 1 wrong name in 600 (20 copies) to 23/600 (100 copies). This is why the UI says "strong hint, not proof" and why at least 10 swappable words are required. |
| New packages (resolve cleanly) | `qr_flutter 4.1.0`, `image_picker 1.2.3` (already a transitive dependency), `google_mlkit_text_recognition 0.17.1` (Android only; kept out of web by a conditional export). |
| Verification of the reference code | In a copy of `app/`: `flutter analyze` **no issues**; full `flutter test` **129 passed, 1 skipped**; `flutter build web --release --base-href /nosus-canary/` **OK**; release APK (arm64) **built, 34.4 MB, package `foo.nosus.canary`**; contract `hardhat test` **5 passing**; edge function `deno check` **OK**. Details: [reference/VERIFICATION.md](reference/VERIFICATION.md). The SQL and the live flow have **not** run yet (they need approvals). |

---

## 3. Architecture

```
 SENDER DEVICE (APK or web)                    SUPABASE (ffidvfguojalzpclipzi)           MONAD TESTNET
 ─────────────────────────────                 ─────────────────────────────────        ─────────────
 note text ─► buildCanaryPlan (slots)
          ─► N random codewords (secret)
          ─► N copies (+ invisible marker)
          ─► AES encrypt each (key K)  ──POST create──►  edge fn `canary`
             digests = sha256(salt:i:copy)               ├─ insert canary_notes / canary_copies
             copiesHash = sha256(all digests)            └─ relayer key ── sealNote(noteId32, N, copiesHash, expiry) ──► NoSusCanary
 owner record (plan, codewords, key, salt,
 ownerSecret) saved ONLY on this device
 link = <origin><base>/#/canary/<noteId>?k=<K>

 READER BROWSER                                                                           
 ──────────────                                                                           
 opens link, types name ──POST open──►  edge fn `canary`
                                        ├─ canary_assign_copy(note, sha256(device), name)  (same copy on retry)
                                        └─ relayer key ── openCopy(noteId32, i, readerTag) ──► NoSusCanary
 ◄── copy i ciphertext + tx hash ──
 decrypt with K from fragment → "Copy i+1 of N · made for <name>"

 SENDER DASHBOARD ──POST status (ownerSecret)──► list of opened copies (name, time, tx)
 LEAK CHECK: matchCanaryLeak(leak, plan, codewords) runs locally → copy i → name from status
```

### IDs and encodings (the contract between the components; do not change)

| Thing | Format | Made by |
|---|---|---|
| `noteId` | UUID v4, lowercase with dashes | sender app (`Uuid().v4()`) |
| Chain note id | `0x` + sha256(`"nosus-canary:" + noteId`), 32 bytes | app **and** edge function (must match). Known answer: noteId `1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed` → `0xb8168efcc5c17afc454283c0e2237b39f5dc917d39ab0eb0f540f544b9878f2e` |
| Key `k` | 64 lowercase hex characters (AES-256) | sender app. Only ever in the link fragment |
| Per-copy IV | 32 hex characters (16 bytes), stored beside the ciphertext | sender app |
| Ciphertext | base64 from `encrypt` package `Encrypter(AES(key)).encrypt(text, iv:)`, the same setup as Burn Notes | sender app |
| Copy digest | sha256(`"<saltHex>:<index>:<copy text>"`) hex | sender app (the salt never leaves the device) |
| `copies_hash` | `0x` + sha256(concatenation of the digests in index order) | sender app → chain |
| Owner secret | 64 hex characters. The server stores `sha256(ownerSecret)` as `owner_hash` | sender app |
| Device id | UUID v4 per browser or app install (SharedPreferences) | reader app. The server stores sha256(`"device:" + id`) |
| Reader tag (on chain) | `0x` + sha256(`"<CANARY_TAG_SALT>:<noteId>:<copyIndex>:<deviceHash>"`) | edge function |
| Reader link | `<origin><basePath>/#/canary/<noteId>?k=<key>` | sender app |
| Invisible marker | U+2060, then 12 bits as U+200B (0) / U+200C (1), then U+2060. 10 data bits hold copyIndex+1 and 2 check bits hold popcount%4. Inserted after the 1st, 11th, 21st… word | fingerprint engine |

### Components
- **Contract** `NoSusCanary.sol`: `sealNote`, `openCopy`, `noteOf`, `copyOf`, `setRelayer`. Writes are relayer-only; the owner manages relayers.
- **DB** (`20260919090000_nosus_canary.sql`): tables `canary_notes`, `canary_copies` and `canary_relayer_leases`, and functions `canary_assign_copy`, `canary_lease_relayer` and `canary_release_relayer`. RLS is on with **no policies**, so only the service role can read or write.
- **Edge function** `canary` (one function, actions `create`/`open`/`status`): uses viem to send transactions from a **pool of relayer keys**. Each key is leased for one in-flight transaction, so nonces never collide.
- **Flutter** `lib/features/canary/`: domain (fingerprint engine, link, models), data (crypto, API, store, repository) and presentation (entry card, home, composer, created/QR, note dashboard, leak check, reader), plus `ocr/` (ML Kit on Android, stub on web).

---

## 4. File map

All sources are in `docs/canary/reference/`, in the same relative layout as their destination.

| Destination (relative to `nosus-monad/`) | Action | Phase |
|---|---|---|
| `app/lib/features/canary/**` (19 files) | copy | 1 |
| `app/test/unit/canary_fingerprint_test.dart`, `canary_link_test.dart` | copy | 1 |
| `app/lib/main.dart`, `app/lib/core/utils/web_links.dart`, `app/lib/services/screenshot_guard.dart`, `app/lib/features/monad/presentation/experiment_frame.dart`, `app/lib/features/onboarding/presentation/screens/welcome_screen.dart`, `app/lib/features/workspace/presentation/pages/workspace_tab.dart`, `app/web/index.html`, `app/web/manifest.json`, `app/android/app/build.gradle.kts`, `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/proguard-rules.pro` | **edited by script** `reference/tools/canary_edits.js` (never by hand) | 1 |
| `app/pubspec.yaml`, `app/pubspec.lock` | `flutter pub add …` | 1 |
| `contracts/contracts/NoSusCanary.sol`, `contracts/test/NoSusCanary.test.ts`, `contracts/scripts/deploy-canary.ts`, `contracts/scripts/canary-relayers.ts` | copy | 2 |
| `app/supabase/migrations/20260919090000_nosus_canary.sql` | copy | 3 |
| `app/supabase/functions/canary/index.ts` | copy | 4 |
| `app/supabase/config.toml` | append 2 lines | 4 |
| `.gitignore` | append 2 lines | 0 |
| `AGENTS.md`, `app/AGENTS.md`, `docs/STATUS.md` | small documented edits | 0 / 7 |

---

## 5. Phases

### Phase 0 — Preflight (15 min)

**0.1 Check location and state** (Git Bash or PowerShell):
```bash
cd /c/Users/shubh/_Active_Projects/NO_SUS/nosus-monad
git status --short | head -20
git branch --show-current
```
DONE WHEN: you are in `nosus-monad`, and the branch is `codex/flutter-monad-integration` or `feat/nosus-canary`.

**0.2 Create the work branch.** `-c` carries the uncommitted work along; nothing is lost:
```bash
git switch -c feat/nosus-canary
```
DONE WHEN: `git branch --show-current` prints `feat/nosus-canary`.

**0.3 Ignore rules.** Append these two lines to `nosus-monad/.gitignore`. The first stops the
Supabase CLI temp files (the pooler URL and bootstrap SQL) from being committed. The second keeps
the relayer key file out of git.
```
app/supabase/.temp/
*.local.json
```
DONE WHEN: `git check-ignore -v app/supabase/.temp/project-ref contracts/.canary-relayers.local.json` prints a rule for both paths. (The second file does not exist yet; `check-ignore` still reports the matching rule.)

**0.4 [OWNER APPROVAL] Baseline commit.** Ask: *"May I commit the current uncommitted work
(including the untracked Flutter `app/`) as a baseline on `feat/nosus-canary`, so the Canary
changes can be reviewed as a clean diff?"* If yes:
```bash
git add -A
git status --short | grep -E "\.env|\.local\.json|supabase/\.temp" && echo "STOP: secret-like file staged" || true
git commit -m "chore: baseline Flutter app before NO SUS Canary"
```
If the grep prints anything, run `git reset` and stop. DONE WHEN: `git status --short` is empty.

**0.5 Record the owner decision in `AGENTS.md`.** This lets later agents work on Canary without
being blocked by the older naming and Gate T1 rules. It should already have been done when this plan
was written; check that a section titled `## Current workstream: NO SUS Canary` exists near the
top of `nosus-monad/AGENTS.md`. If it does not, add the section shown in Appendix A.
DONE WHEN: the section exists.

### Phase 1 — Flutter code (40 min, no approvals needed)

**1.1 Copy the new Canary files** (Git Bash):
```bash
cd /c/Users/shubh/_Active_Projects/NO_SUS/nosus-monad
cp -r docs/canary/reference/app/lib/features/canary app/lib/features/
cp docs/canary/reference/app/test/unit/canary_fingerprint_test.dart app/test/unit/
cp docs/canary/reference/app/test/unit/canary_link_test.dart app/test/unit/
find app/lib/features/canary -type f | sort
```
DONE WHEN: the listing shows exactly these 19 files (under `app/lib/features/canary/`):
- `data/`: `canary_api.dart`, `canary_crypto.dart`, `canary_repository.dart`, `canary_store.dart`
- `domain/`: `canary_fingerprint.dart`, `canary_link.dart`, `canary_models.dart`
- `ocr/`: `canary_ocr.dart`, `canary_ocr_mlkit.dart`, `canary_ocr_stub.dart`
- `presentation/`: `canary_composer_screen.dart`, `canary_created_screen.dart`,
  `canary_entry_card.dart`, `canary_home_screen.dart`, `canary_leak_check_screen.dart`,
  `canary_note_screen.dart`, `canary_providers.dart`, `canary_reader_screen.dart`, `canary_ui.dart`

**1.2 Apply the edits to existing files with the script. Run it exactly once.**
```bash
cd /c/Users/shubh/_Active_Projects/NO_SUS/nosus-monad/app
node ../docs/canary/reference/tools/canary_edits.js
```
DONE WHEN: it prints `ALL EDITS APPLIED`. If it prints `ANCHOR NOT FOUND`, the file already
differs from what the script expects. Run `git diff <that file>`. If the Canary edit is already
there, the script ran before, so skip this step. Otherwise stop and ask the owner. **Never run the
script twice on the same files.**

What the script changes (so you can review `git diff`):
- `main.dart`: imports, `extractCanaryToken()`, the standalone reader branch (runs before the
  redemption branch), the Android link routing branch, `title: 'NO SUS'`, and the `'/canary'` route.
- `experiment_frame.dart`: banner text → `NO SUS · Monad testnet · use harmless test notes only`.
- `web_links.dart`: `kWebAppOrigin` and `kWebAppBasePath` read `--dart-define`s (`WEB_APP_ORIGIN`,
  `WEB_APP_BASE_PATH`) so links minted by the APK point at the deployed web app.
- `screenshot_guard.dart`: with `NOSUS_ALLOW_SCREEN_CAPTURE=true` it calls `disableSecure` and skips
  the screenshot popups (for projector mirroring).
- `welcome_screen.dart` and `workspace_tab.dart`: the `MonadEntryCard` is replaced by `CanaryEntryCard`.
  (The Monad screen still exists at route `/monad`.)
- `web/index.html` and `web/manifest.json`: names → `NO SUS`.
- `android/app/build.gradle.kts`: `applicationId = "foo.nosus.canary"`.
- `AndroidManifest.xml`: removes the `app.nosus.foo` App Links filter and fixes its comment.
- `proguard-rules.pro`: appends 4 `-dontwarn` rules for ML Kit's optional script recognizers.
  Without them, the release APK fails at R8 with "Missing class …ChineseTextRecognizerOptions"
  (verified).

**1.3 Add the packages** (PowerShell):
```powershell
Set-Location C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad\app
FLUTTER pub add qr_flutter image_picker google_mlkit_text_recognition
```
DONE WHEN: `pubspec.yaml` lists all three under `dependencies:`. The expected resolved versions are
qr_flutter 4.1.0, image_picker 1.2.3 and google_mlkit_text_recognition 0.17.1.

**1.4 Check** (PowerShell, in `app`):
```powershell
FLUTTER analyze
FLUTTER test test/unit/canary_fingerprint_test.dart test/unit/canary_link_test.dart test/unit/deep_link_parsing_test.dart test/widget/welcome_screen_test.dart test/widget/monad_screen_test.dart
FLUTTER test
```
DONE WHEN: analyze prints `No issues found!` and both test commands end with `All tests passed!`.
(The first analyze run takes about 3 minutes.)

**1.5 [OWNER APPROVAL] Commit:** `git add -A && git commit -m "feat(canary): NO SUS Canary Flutter feature"`

### Phase 2 — Contract (30 min; deploy and relayers need approval and MON)

**2.1 Copy and test** (Git Bash):
```bash
cd /c/Users/shubh/_Active_Projects/NO_SUS/nosus-monad
cp docs/canary/reference/contracts/contracts/NoSusCanary.sol contracts/contracts/
cp docs/canary/reference/contracts/test/NoSusCanary.test.ts contracts/test/
cp docs/canary/reference/contracts/scripts/deploy-canary.ts contracts/scripts/
cp docs/canary/reference/contracts/scripts/canary-relayers.ts contracts/scripts/
cd contracts && npx hardhat test
```
DONE WHEN: the output shows `11 passing` (6 existing NoSusMonadDrops tests plus 5 NoSusCanary tests)
and prints `sealNote gasUsed≈73833` and `openCopy gasUsed≈78403`.

**2.2 Owner prepares the deployer wallet (owner does this, not the agent):**
1. Use a **testnet-only** wallet. Get ≥ 10 MON from the Blitz platform (https://blitz.devnads.com,
   50 MON per attendee) or a Monad faucet.
2. Create `nosus-monad/contracts/.env` (git-ignored by the `.env` rule) containing:
   ```
   DEPLOYER_PRIVATE_KEY=0x<64 hex>
   MONAD_RPC_URL=https://testnet-rpc.monad.xyz
   ```
DONE WHEN: the owner confirms the file exists. The agent must never print it: use
`Test-Path contracts/.env` only.

**2.3 [OWNER APPROVAL] Deploy** (PowerShell, in `contracts`). The env loader keeps the key out of
command history:
```powershell
Set-Location C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad\contracts
Get-Content .env | ForEach-Object { if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.+?)\s*$') { Set-Item -Path ("Env:" + $matches[1]) -Value $matches[2] } }
$env:CONFIRM_MONAD_DEPLOY = "1"
npx hardhat run scripts/deploy-canary.ts --network monadTestnet
```
DONE WHEN: it prints `NoSusCanary deployed at: 0x…`. Save that address as `CANARY_CONTRACT_ADDRESS`
in the Progress log and in `docs/STATUS.md`. Open `https://testnet.monadscan.com/address/<address>`
to see it.

**2.4 [OWNER APPROVAL] Relayers.** Relayers are 10 fresh testnet keys, 0.5 MON each: about 5 MON
total, enough for about 320 opens. Same PowerShell session as 2.3:
```powershell
$env:CANARY_CONTRACT_ADDRESS = "0x<address from 2.3>"
$env:CANARY_RELAYER_COUNT = "10"
$env:CANARY_RELAYER_FUND_MON = "0.5"
npx hardhat run scripts/canary-relayers.ts --network monadTestnet
```
DONE WHEN: it prints `relayer ready: 0x…` 10 times and then `10 relayers ready`. The keys are in
`contracts/.canary-relayers.local.json`, which is git-ignored. **Never print or commit it.** It is
safe to re-run: it tops up balances and skips relayers that are already allowed.

### Phase 3 — Database (10 min; needs approval)

**3.1 Copy the migration** (Git Bash):
```bash
cd /c/Users/shubh/_Active_Projects/NO_SUS/nosus-monad
cp docs/canary/reference/app/supabase/migrations/20260919090000_nosus_canary.sql app/supabase/migrations/
```

**3.2 [OWNER APPROVAL] Apply it to the experiment project ONLY.** Run from `app` (PowerShell),
and check the project ref first:
```powershell
Set-Location C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad\app
Get-Content supabase\.temp\project-ref      # MUST print ffidvfguojalzpclipzi — otherwise STOP
supabase db query --linked --file supabase/migrations/20260919090000_nosus_canary.sql
```
DONE WHEN: no error is printed. Then verify:
```powershell
supabase db query --linked "select to_regclass('public.canary_notes') as notes, to_regclass('public.canary_copies') as copies, to_regclass('public.canary_relayer_leases') as leases;"
```
All three columns must be non-null. Then confirm the public key cannot read the table (Git Bash):
```bash
curl -s "https://ffidvfguojalzpclipzi.supabase.co/rest/v1/canary_copies?select=*&limit=1" \
  -H "apikey: sb_publishable_D_mmlb1jjS9Cl6QCuFwEJw_zPAb6kHS" \
  -H "Authorization: Bearer sb_publishable_D_mmlb1jjS9Cl6QCuFwEJw_zPAb6kHS"
```
It must return `permission denied` (code 42501) or `[]`, never rows. **Do not** run `supabase db push`.

### Phase 4 — Edge function (20 min; needs approval)

**4.1 Copy and configure** (Git Bash):
```bash
cd /c/Users/shubh/_Active_Projects/NO_SUS/nosus-monad
mkdir -p app/supabase/functions/canary
cp docs/canary/reference/app/supabase/functions/canary/index.ts app/supabase/functions/canary/index.ts
printf '\n[functions.canary]\nverify_jwt = false\n' >> app/supabase/config.toml
tail -3 app/supabase/config.toml
```
DONE WHEN: the tail shows `[functions.canary]` and `verify_jwt = false`.

**4.2 [OWNER APPROVAL] Secrets** (PowerShell; the values are never printed):
```powershell
Set-Location C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad\contracts
$keys = node -e "console.log(require('./.canary-relayers.local.json').join(','))"
$salt = node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
supabase secrets set --project-ref ffidvfguojalzpclipzi "CANARY_CONTRACT_ADDRESS=$env:CANARY_CONTRACT_ADDRESS" "CANARY_RELAYER_KEYS=$keys" "CANARY_TAG_SALT=$salt" "MONAD_RPC_URL=https://testnet-rpc.monad.xyz"
supabase secrets list --project-ref ffidvfguojalzpclipzi
```
DONE WHEN: the list shows CANARY_CONTRACT_ADDRESS, CANARY_RELAYER_KEYS, CANARY_TAG_SALT and
MONAD_RPC_URL (as digests only). Never change `CANARY_TAG_SALT` after readers have opened copies.

**4.3 [OWNER APPROVAL] Deploy** (PowerShell, in `app`; `--use-api` avoids Docker):
```powershell
Set-Location C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad\app
supabase functions deploy canary --project-ref ffidvfguojalzpclipzi --no-verify-jwt --use-api
```
DONE WHEN: the output says the function was deployed.

**4.4 Smoke test** (Git Bash). These must return exactly these errors:
```bash
K="sb_publishable_D_mmlb1jjS9Cl6QCuFwEJw_zPAb6kHS"; U="https://ffidvfguojalzpclipzi.supabase.co/functions/v1/canary"
curl -s -X POST "$U" -H "apikey: $K" -H "Content-Type: application/json" -d '{"action":"nope"}'
# -> {"error":"Unknown action"}
curl -s -X POST "$U" -H "apikey: $K" -H "Content-Type: application/json" -d '{"action":"status","note_id":"00000000-0000-4000-8000-000000000000","owner_secret":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}'
# -> {"error":"Note not found."}
curl -s -X POST "$U" -H "apikey: $K" -H "Content-Type: application/json" -d '{"action":"open","note_id":"00000000-0000-4000-8000-000000000000","device_id":"00000000-0000-4000-8000-000000000001","reader_name":"Test"}'
# -> {"error":"This Canary link is not valid."}
```
If you get `canary is not configured (…)`, a secret is missing (see 4.2). If you get 401, the
function was deployed without `--no-verify-jwt`.

### Phase 5 — Web build and GitHub Pages (20 min; the public repo needs approval)

**5.1 Build** (PowerShell):
```powershell
Set-Location C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad\app
FLUTTER build web --release --base-href /nosus-canary/
Remove-Item build\web\CNAME -ErrorAction SilentlyContinue
Select-String -Path build\web\index.html -Pattern '<base href="/nosus-canary/">'
```
DONE WHEN: `Select-String` prints the base tag and `build\web\CNAME` no longer exists.

**5.2 Local check before publishing:**
`FLUTTER run -d chrome --web-port 8686`, then walk through Phase 7 steps 1–6 on
`http://localhost:8686/#/canary`.

**5.3 [OWNER APPROVAL] First publish.** This creates the **public** repo `https-shubhamsahu/nosus-canary`
(PowerShell):
```powershell
$Web = "C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad\app\build\web"
$Pub = "C:\Users\shubh\_Active_Projects\NO_SUS\nosus-canary-pages"
if (Test-Path $Pub) { Remove-Item -Recurse -Force $Pub }
New-Item -ItemType Directory -Force $Pub | Out-Null
Copy-Item -Recurse "$Web\*" $Pub
New-Item -ItemType File -Force "$Pub\.nojekyll" | Out-Null
Set-Location $Pub
git init -b main
git add -A
git commit -m "Deploy NO SUS Canary web"
gh repo create nosus-canary --public --source . --push
gh api -X POST repos/https-shubhamsahu/nosus-canary/pages -f "source[branch]=main"
```
**Later redeploys** (after rebuilding with 5.1), in PowerShell:
```powershell
$Web = "C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad\app\build\web"
$Pub = "C:\Users\shubh\_Active_Projects\NO_SUS\nosus-canary-pages"
Set-Location $Pub
Get-ChildItem -Force | Where-Object { $_.Name -ne '.git' } | Remove-Item -Recurse -Force
Copy-Item -Recurse "$Web\*" $Pub
Remove-Item "$Pub\CNAME" -ErrorAction SilentlyContinue
New-Item -ItemType File -Force "$Pub\.nojekyll" | Out-Null
git add -A; git commit -m "Redeploy NO SUS Canary web"; git push
```

DONE WHEN (within about 3 minutes): `curl -sI https://https-shubhamsahu.github.io/nosus-canary/`
returns `200`, and the page shows NO SUS.

### Phase 6 — APK (15 min build time)

**6.1 Build** (PowerShell, one line; do not run other heavy jobs at the same time):
```powershell
Set-Location C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad\app
FLUTTER build apk --release --target-platform android-arm64 --dart-define=WEB_APP_ORIGIN=https://https-shubhamsahu.github.io --dart-define=WEB_APP_BASE_PATH=/nosus-canary --dart-define=NOSUS_ALLOW_SCREEN_CAPTURE=true
Copy-Item build\app\outputs\flutter-apk\app-release.apk C:\Users\shubh\_Active_Projects\NO_SUS\NO-SUS-Canary.apk
```
DONE WHEN: `Built build\app\outputs\flutter-apk\app-release.apk` is printed and `NO-SUS-Canary.apk`
exists. Signing falls back to the debug key because there is no `key.properties`. That is fine for
sideloading; **never upload this APK to Play.**

**6.2 Install** (phone with USB debugging on):
```powershell
& "C:\Users\shubh\AppData\Local\Android\Sdk\platform-tools\adb.exe" install -r build\app\outputs\flutter-apk\app-release.apk
```
DONE WHEN: it prints `Success` and the phone shows an app called **NO SUS**. The package is
`foo.nosus.canary`. If the Play Store NO SUS is also installed, both icons say NO SUS; for the
demo, uninstall the store one or move it to another screen.

### Phase 7 — End-to-end acceptance (20 min)

Use the deployed web app, a laptop and at least two phones. Tick each step:
1. Open `https://https-shubhamsahu.github.io/nosus-canary/#/canary` → **Use the demo note** →
   100 readers → 1 day → **Create Canary link**. The link, the QR code and "Sealed on Monad testnet ·
   view proof" appear, and the proof opens monadscan.
2. Phone A scans the QR → name "Asha" → **Open my copy** → it shows "Copy N of 100 · made for Asha"
   and the proof link works.
3. Phone A refreshes the page and opens again → **same** copy number.
4. Phone B (or an incognito window) → name "Ben" → a **different** copy number.
5. On the laptop, **Who opened it** shows Asha and Ben within about 3 s, each with ✓.
6. Ben selects all his text and copies it → laptop **Check a leak** → paste → **Find the copy** →
   "🐤 The canary sang. Copy #… — Ben".
7. Paste the original demo note → "This is your own original text".
8. Paste `the quick brown fox` → "Not enough of the note to tell" (no name).
9. APK: Welcome → **NO SUS Canary** → create a note on the phone → open it from another phone →
   take a screenshot of that reader's copy → on the APK, **Check a leak → Read a screenshot** →
   the right copy is named.
10. Mirror the APK screen (e.g. scrcpy) → it is **not** black.
11. Record the results and the contract address in `docs/STATUS.md` (Appendix B template).

### Phase 8 — Demo runbook (peer vote at the event)

**Setup:**
- Create the demo note on the **presenter phone (APK)** with **100 readers**. Leak checks work
  only on the device that created the note.
- Mirror the phone to the projector (for example scrcpy over USB). Only the owner may install
  software.
- Show the QR (**Show link & QR**) on the projector.

**The flow (about 90 s):**
1. "Everyone scan this — it's our team's secret."
2. The Seen-by list fills live.
3. A volunteer screenshots their copy and posts it in a WhatsApp group shown on screen.
4. On the phone, **Check a leak → Read a screenshot** → "🐤 Copy #37 — Priya".
5. One line on Monad: "Which copy is whose was recorded on Monad before anyone could read it, so
   nobody can reshuffle the blame afterwards."

**Fallbacks:**
- If OCR misreads the screenshot, paste the text instead.
- If mirroring fails, create the note on the laptop web app instead and use paste.
- If the venue Wi-Fi is slow, use a phone hotspot for the presenter devices.

### Phase 9 — After the hackathon
- Delete `docs/canary/reference/` after its files are committed in their real locations. The
  constitution says: no duplicate files.
- Stretch goals: an owner link to move leak checks to another device, Google sign-in for readers,
  and alerts when a copy is opened.

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `--base-href should start and end with /` with `C:/Program Files/Git/...` | Git Bash path conversion | Use PowerShell, or `MSYS_NO_PATHCONV=1` |
| `ANCHOR NOT FOUND` from `canary_edits.js` | The file changed, or the script already ran | `git diff <file>`; do not run it twice (step 1.2) |
| APK build: `Could not start thread DartWorker` | Out of memory or threads | Close other heavy jobs and rebuild |
| APK build fails in `R8Task` / "Missing class com.google.mlkit.vision.text.chinese…" | The ML Kit `-dontwarn` rules are missing | Step 1.2 adds them. Check the end of `android/app/proguard-rules.pro`; `build/app/outputs/mapping/release/missing_rules.txt` lists what R8 wants |
| Phone: "App not installed" | Old APK with the same id but a different signature | `adb uninstall foo.nosus.canary`, then install again |
| Reader: "NO SUS is busy" | All relayer keys have transactions in flight | Tap again. For big rooms add relayers: re-run 2.4 with a higher count, then 4.2 and 4.3 |
| Reader: "Could not record your copy on Monad" | RPC hiccup, or a relayer is out of MON | Retry. Check relayer balances on monadscan and top up with 2.4 |
| Reader: "Every copy of this note has been opened" | All N copies are taken | Create a new note with more readers |
| Function returns 401 | Deployed with JWT verification | Redeploy with `--no-verify-jwt` |
| `canary is not configured (X)` | Secret X is missing | Step 4.2 |
| Contract deploy hangs or fails with network errors | Default RPC `rpc.testnet.monad.xyz` is dead | Set `MONAD_RPC_URL=https://testnet-rpc.monad.xyz` in `contracts/.env` |
| Pages shows 404 or redirects to monad.nosus.foo | `CNAME` was published | Delete `CNAME` from the publish folder and push |
| Screenshot or mirror shows black | Built without `NOSUS_ALLOW_SCREEN_CAPTURE=true` | Rebuild with the define (6.1) |
| Composer: "Found X of the Y swappable words" | Note too short for that many readers | Longer note, fewer readers, or the demo note |
| Leak check names nobody | Too little text, or text edited or mixed from several copies | Paste more of the leak. Working as designed |

## 7. If time runs out, cut in this order
1. OCR "Read a screenshot" (paste still works). 2. "See the magic". 3. The APK: demo from the
laptop web app plus phone browsers. **Never cut:** the reader flow, Seen by, the leak check by paste.

## 8. Appendix A — AGENTS.md section (owner decision)
```
## Current workstream: NO SUS Canary (owner decision, 19 Sep 2026)
- Brand: "NO SUS". Feature: "NO SUS Canary". This supersedes the "NO SUS — Monad Experiment"
  naming rule for user-facing text.
- Build plan: docs/canary/NOSUS_CANARY_BUILD_PLAN.md (follow it step by step).
- Canary is server-gated copy delivery, disclosed as such. It does not use Lit, does not change
  Gate T1, and does not change monadThresholdVerified.
- Still requires explicit owner approval each time: contract deploys, funding wallets, applying
  SQL, setting secrets, deploying functions, creating public repos or Pages, commits and pushes.
```

## 8b. Appendix B — STATUS.md entry template
```
## NO SUS Canary — <date>
- Contract NoSusCanary: <address> (monadscan link)
- Relayers: <count>, funded <amount> MON each
- Migration 20260919090000_nosus_canary.sql applied to ffidvfguojalzpclipzi: <yes/date>
- Edge function `canary` deployed: <yes/date>
- Web: https://shubham-sahu.me/nosus-canary/#/canary
- APK: NO-SUS-Canary.apk (foo.nosus.canary, debug-signed, sideload only)
- Acceptance (Phase 7): steps 1–10 <pass/fail notes>
```

## 9. Progress log (tick as you go; add dates, notes and addresses)
- [x] 0.1 location/branch checked
- [x] 0.2 branch `feat/nosus-canary`
- [x] 0.3 .gitignore rules
- [x] 0.4 baseline commit (owner OK)
- [x] 0.5 AGENTS.md section present
- [x] 1.1 Canary files copied
- [x] 1.2 edit script applied once
- [x] 1.3 packages added
- [x] 1.4 analyze clean, tests green
- [x] 1.5 commit (owner OK)
- [x] 2.1 contract tests 11 passing
- [x] 2.2 deployer .env ready (owner)
- [x] 2.3 deployed: CANARY_CONTRACT_ADDRESS = 0xb1a1858866122c84cf97861ca815fb070e010e68
- [x] 2.4 relayers ready (count 10, 0.5 MON each)
- [x] 3.2 migration applied + verified
- [x] 4.2 secrets set
- [x] 4.3 function deployed
- [x] 4.4 smoke tests pass
- [x] 5.1 web built, CNAME removed
- [x] 5.3 Pages live at https://shubham-sahu.me/nosus-canary/#/canary
- [x] 6.1 APK built → NO-SUS-Canary.apk
- [ ] 6.2 installed on demo phone
- [ ] 7 acceptance 1–10 passed
- [ ] 8 demo rehearsed twice

Reference-code verification when this plan was written (19 Sep 2026): analyze clean; full test suite
129 passed; web release build OK; arm64 release APK built (34.4 MB, `foo.nosus.canary`); hardhat 5/5
for NoSusCanary; deno check OK for the edge function. See `reference/VERIFICATION.md`.
