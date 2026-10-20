# Contributing

Thanks for looking. Issues and pull requests are welcome. For security problems, follow
[SECURITY.md](SECURITY.md) instead of opening an issue.

## Where things are

| Area | Code | Read first |
|---|---|---|
| Canary UI and fingerprinting | `app/lib/features/canary/` | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Relayer (Supabase Edge Function) | `app/supabase/functions/canary/` | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Receipt format and libraries | `packages/receipts-ts/`, `packages/receipts-dart/`, `packages/test-vectors/` | [docs/RECEIPTS_SPEC.md](docs/RECEIPTS_SPEC.md) |
| Schema | `app/supabase/migrations/` (Canary: `2026091909*`, `2026101009*`) | [docs/SELF_HOSTING.md](docs/SELF_HOSTING.md) |

`app/` is the full NO SUS Flutter app. The deployed site is the standalone Canary build
(`--dart-define=NOSUS_CANARY_ONLY=true`, base href `/nosus-canary/`).

## Rules

- Memos carry hashes only. Never put note text, keys, names or device ids on chain. The memo format
  is frozen at v1; any change needs a new version, new test vectors, and both libraries updated.
- Secrets live in Supabase function secrets or git-ignored files ([.env.example](.env.example)
  lists them). The Supabase publishable key in `app/lib/config/supabase_credentials.dart` is
  public by design.
- Keep `CANARY_MONAD` (Flutter) off and `CANARY_CONTRACT_ADDRESS` (relayer) unset. That legacy path
  is not part of the product.
- Never claim screenshot prevention, legal proof, identity proof, or proof that a human read a note.
- Use harmless test notes on the devnet demo.
- Migrations are immutable: add a new file, never edit an applied one. Apply single files with
  `supabase db query --linked --file …`; don't run `supabase db push` against the hosted project.
- After changing the word list in `canary_fingerprint.dart`, run the fingerprint harness; it must
  end with `FAILURES: 0`.
- Keep changes small. Don't reformat unrelated files.

## Checks (CI runs all of these)

```bash
(cd app && flutter analyze && flutter test && dart run tool/canary_fingerprint_harness.dart)
(cd app/supabase/functions/canary && deno check index.ts && deno test --allow-env)
(cd packages/receipts-ts && deno check mod.ts cli.ts && deno lint && deno fmt --check && deno test)
(cd packages/receipts-dart && dart pub get && dart analyze && dart format --set-exit-if-changed . && dart test)
```

## License

By contributing you agree that your contribution is licensed under [Apache-2.0](LICENSE).
