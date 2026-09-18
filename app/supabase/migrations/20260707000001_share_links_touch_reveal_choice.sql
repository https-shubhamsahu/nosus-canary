-- Migration: 20260707000001_share_links_touch_reveal_choice.sql
-- Lets the SENDER (the file's uploader, who creates the share link) choose
-- whether a recipient must touch-and-hold to reveal the document, instead of
-- this being forced on for every link. Defaults to true (unchanged behavior
-- for existing links). The existing `feature_flags.securesend_blur_enforced`
-- global admin flag still applies as a platform-wide override on top of this
-- per-link choice (share-fetch combines them with AND).
--
-- Purely additive: one new column on an existing table.
--
-- Renumbered from 20260707000000 (2026-08-01): that timestamp collided with
-- 20260707000000_drop_orphaned_revoke_device.sql — two files sharing one
-- version broke the remote ledger, since supabase_migrations.schema_migrations
-- has version as its primary key. This file's column was already live in
-- production under the old timestamp; the rename is bookkeeping only.

ALTER TABLE public.share_links
  ADD COLUMN IF NOT EXISTS require_touch_reveal BOOLEAN NOT NULL DEFAULT true;
