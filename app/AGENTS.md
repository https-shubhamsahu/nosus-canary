# NO SUS Canary: Flutter app

This is the NO SUS Flutter app (copied from the production `no_sus` repo at
`ec29fdae94a68fefcb5efea2797224dc2245549c`). NO SUS Canary lives in `lib/features/canary/`. The
root `AGENTS.md` still applies.

- The deployed site is the standalone Canary build: `--dart-define=NOSUS_CANARY_ONLY=true`, base
  href `/nosus-canary/`. Without that flag you get the full NO SUS app, with Canary reachable from
  the welcome screen and `#/canary`.
- Backend: `ffidvfguojalzpclipzi` only. Never apply this fork's SQL to the production project. No
  production users or storage were copied. The publishable Supabase key is a public client key.
- Native source is kept for parity. Do not release it with the production application or signing
  identity.
- Leave `CANARY_MONAD` off (default). User-facing text names Solana only.
- After changing the word list in `canary_fingerprint.dart`, run
  `dart run tool/canary_fingerprint_harness.dart`; it must end with `FAILURES: 0`.
- Run `flutter analyze` and `flutter test` before every commit. Do not reformat unrelated copied
  files. Migrations are immutable; add new ones.
