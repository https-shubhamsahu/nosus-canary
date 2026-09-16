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
