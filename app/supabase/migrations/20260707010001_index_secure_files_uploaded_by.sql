-- Migration: 20260707010001_index_secure_files_uploaded_by.sql
-- Covers the secure_files_uploaded_by_fkey foreign key, flagged by the
-- Supabase performance advisor as unindexed (matters for profile deletes,
-- which cascade through this column via account-manager).

CREATE INDEX IF NOT EXISTS idx_secure_files_uploaded_by
  ON public.secure_files (uploaded_by);
