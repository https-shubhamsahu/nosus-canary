# Supabase backend

This directory is for a **new, isolated** Supabase project for the Monad
experiment. It must never be linked to production NO SUS.

## Purpose

The backend stores encrypted payloads, Lit metadata, public receipt metadata,
and event-indexing records. It does not accept, derive, log, or return
plaintext or decryption keys.

## Entry points

- `migrations/20260916082811_experiment_drops.sql` — initial RLS-protected
  schema and private encrypted-drop storage bucket
- `../web/src/app/api/` — server-only, allow-listed read API for the live wall
  and receipt verifier

## Rules

- Migrations are append-only. Make a new migration with `supabase migration new
  <name>`; never rewrite one that has been applied.
- RLS stays enabled. Browser clients receive only the publishable key; the
  service-role key is server-only.
- Do not apply this migration, link a project, create a bucket remotely, or
  store real notes until the root finalization gate is explicitly approved.

## NO SUS Canary (separate schema under `app/supabase/`)

The shipped NO SUS Canary feature does not use this directory. Its schema and the
`canary` edge function live under `app/supabase/` and are applied only to the
experiment project `ffidvfguojalzpclipzi` (never production `rxfnazmusofikwaggntb`).

- `app/supabase/migrations/20260919090000_nosus_canary.sql` — `canary_notes`,
  `canary_copies`, `canary_relayer_leases`; Monad testnet `seal_tx_hash` /
  `open_tx_hash`.
- `app/supabase/migrations/20261010090000_nosus_canary_solana.sql` — adds nullable
  `canary_notes.seal_solana_sig` and `canary_copies.open_solana_sig`, and makes
  `canary_assign_copy` also return `open_solana_sig` (10 Oct 2026, not yet applied).
- Function secrets: `CANARY_CONTRACT_ADDRESS`, `CANARY_RELAYER_KEYS`,
  `CANARY_TAG_SALT`, `MONAD_RPC_URL`; optional `SOLANA_RELAYER_KEYS` (devnet only),
  `SOLANA_RPC_URL`, `SOLANA_MEMO_PROGRAM`. With `SOLANA_RELAYER_KEYS` unset, Solana
  is off and the function behaves as before.
- Apply SQL with `supabase db query --linked --file …`, never `supabase db push`
  (`docs/canary/NOSUS_CANARY_BUILD_PLAN.md`, rule 5).
