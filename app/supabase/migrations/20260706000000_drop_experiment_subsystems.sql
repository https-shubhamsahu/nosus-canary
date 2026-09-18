-- Migration: 20260706000000_drop_experiment_subsystems.sql
-- Deep cleanup (founder-approved "full nuke", 2026-07-06): removes the unused
-- experiment subsystems from the live database. The corresponding SOURCE CODE
-- (Sealed feature, FHE service, storage-router) stays in the repo, shelved —
-- a fresh environment replaying all migrations recreates then drops these,
-- landing in the same state.
--
-- Drops (all tables were empty at execution time):
--   FHE subsystem:    fhe_nonces, fhe_key_metadata, fhe_compute_jobs, fhe_events
--   Sealed subsystem: sealed_profiles, arenas, arena_members, seals, matches, invites
--   Multi-cloud:      storage_objects
--   Orphan:           devices (0 rows, unreferenced by any code)
-- Functions whose only consumers are dropped here: is_arena_member, join_arena,
--   fhe_touch_updated_at, storage_objects_touch_updated_at.
-- The PRODUCT tables (share_links, share_link_views) and core app tables are
-- NOT touched by this migration.

-- Sealed (children before parent; CASCADE clears policies/triggers/FKs)
DROP TABLE IF EXISTS public.seals CASCADE;
DROP TABLE IF EXISTS public.matches CASCADE;
DROP TABLE IF EXISTS public.invites CASCADE;
DROP TABLE IF EXISTS public.arena_members CASCADE;
DROP TABLE IF EXISTS public.arenas CASCADE;
DROP TABLE IF EXISTS public.sealed_profiles CASCADE;
DROP FUNCTION IF EXISTS public.is_arena_member(uuid);
DROP FUNCTION IF EXISTS public.join_arena(uuid);

-- FHE subsystem
DROP TABLE IF EXISTS public.fhe_nonces CASCADE;
DROP TABLE IF EXISTS public.fhe_key_metadata CASCADE;
DROP TABLE IF EXISTS public.fhe_compute_jobs CASCADE;
DROP TABLE IF EXISTS public.fhe_events CASCADE;
DROP FUNCTION IF EXISTS public.fhe_touch_updated_at();

-- Multi-cloud storage router
DROP TABLE IF EXISTS public.storage_objects CASCADE;
DROP FUNCTION IF EXISTS public.storage_objects_touch_updated_at();

-- Orphaned table (exists in live DB only; no repo migration or code references)
DROP TABLE IF EXISTS public.devices CASCADE;
