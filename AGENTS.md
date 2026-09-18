# NO SUS — Monad Experiment agent map

This repository is an isolated, **testnet-only** experiment. Read
[docs/STATUS.md](docs/STATUS.md), then only the local guide for files you will change.

## Current workstream: NO SUS Canary (owner decision, 19 Sep 2026)

- Brand: **NO SUS**. Feature: **NO SUS Canary**. This supersedes the "NO SUS — Monad Experiment"
  naming rule below for user-facing text.
- Build plan: [docs/canary/NOSUS_CANARY_BUILD_PLAN.md](docs/canary/NOSUS_CANARY_BUILD_PLAN.md).
  Follow it step by step; its verified source files are in `docs/canary/reference/`.
- Canary is server-gated copy delivery and is described as such. It does not use Lit, does not
  change Gate T1, and does not change `monadThresholdVerified`.
- Still requires explicit owner approval each time: contract deploys, funding wallets, applying
  SQL, setting secrets, deploying functions, creating public repos or Pages, commits and pushes.

## Product boundaries

- Brand it **NO SUS — Monad Experiment**. Do not call it Rasid and do not change the production
  NO SUS repository, credentials, Supabase project, deployment, or URL.
- Use only harmless, personally owned test notes. Never use credentials, third-party documents,
  employment records, financial information, or sensitive personal data.
- The product may say "threshold-gated decryption after a wallet acknowledgement." It must never
  claim legal proof, a human read, screenshot prevention, serverless deletion, or identity proof.
- The contract must never receive plaintext, encryption keys, salts, filenames, or document content.
- Threshold custody is a release gate, not decoration: if the Monad-to-Lit proof is not clean, do
  not present it as shipped and never substitute a hidden server key-release path.

## How to navigate

| Area | Read first |
|---|---|
| Contract | `contracts/README.md` and `contracts/AGENTS.md` |
| Web app | `web/README.md` and `web/AGENTS.md` |
| Storage schema | `supabase/README.md` |
| Handover | `docs/CURSOR_HANDOFF.md` |
| Lit technical gate | `docs/LIT_MONAD_SPIKE.md` |
| Parallel work | `docs/AGENT_COLLABORATION.md` |

## Working rules

- Use the smallest necessary change. Do not add an abstraction, dependency, code generator, or
  generic utility without a current consumer.
- Keep all secrets in ignored environment files. `NEXT_PUBLIC_*` values are public by design; never
  put service-role keys, private keys, Lit account keys, or test-wallet keys there.
- Work in a dedicated branch and small commits. Update `docs/STATUS.md` and local README files when
  behavior, contracts, or setup changes.
- Normal work uses focused checks and localhost. Do not deploy, fund wallets, apply a Supabase
  migration, or use a real test note without explicit user direction.
- After each substantive response that changes files, ask exactly: "Would you like to finalize today's
  work? If yes, say whether to verify only, build a target, or deploy a named target."

Would you like to finalize today's work? If yes, say whether to verify only, build a target, or deploy a named target.

## Finalization

"Verify only" permits the contract tests, web checks, repository checks, and the real Monad/Lit
technical gate. A deployment additionally needs an explicitly named target.
