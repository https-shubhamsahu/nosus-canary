# Cursor handover

This repository is designed to continue cleanly in Cursor without re-reading the production NO SUS
codebase.

## Open the right folder

Open `C:\Users\shubh\_Active_Projects\NO_SUS\nosus-monad` in Cursor, not `no_sus`.
Cursor automatically loads root `AGENTS.md` and the versioned `.cursor/rules/*.mdc` rules. The rules are
kept small and scoped so unrelated contract or web context is not loaded.

## First Cursor prompt

```text
Read AGENTS.md, docs/STATUS.md, docs/ARCHITECTURE.md, docs/LIT_MONAD_SPIKE.md, and the local README for the area you will touch.
This is the isolated NO SUS — Monad Experiment repository. Continue only the next blocking milestone:
prove Lit threshold decryption against NoSusMonadDrops on Monad testnet using two wallets. Do not touch
the production NO SUS repository, deploy, apply Supabase migrations, or claim the feature is live until
the documented threshold-gate acceptance tests pass. Keep changes small, update STATUS.md, and end your
response with the exact finalization question in AGENTS.md.
```

## How to keep Cursor on track

1. Start each task with the prompt above plus one concrete file/feature request.
2. Let Cursor read only the named local README and files; do not ask it to scan parent directories.
3. Before a new capability, ask it to update `docs/STATUS.md` with the acceptance criteria first.
4. Review `git diff` before allowing a deployment, migration, or contract funding action.
5. When a task is done, commit it and ask Cursor to record the actual check output in `docs/STATUS.md`.

## Escalation rules

Stop and ask for direction if threshold custody cannot bind a Monad wallet to `canDecrypt`, if a design
would put a secret into public calldata, or if a change needs production NO SUS credentials or services.
