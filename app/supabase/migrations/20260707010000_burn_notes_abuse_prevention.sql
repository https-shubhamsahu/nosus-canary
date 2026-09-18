-- Migration: 20260707010000_burn_notes_abuse_prevention.sql
-- burn_notes is the app's only anonymous-write surface (INSERT is open by
-- design — senders may have no account). Three gaps made it abusable:
--
-- 1. No size limit: anyone could insert arbitrarily large ciphertext rows
--    and grow the database unboundedly. The composer is a short text note;
--    100 KB of base64 (~75 KB plaintext) is far beyond any legitimate use.
-- 2. Nothing ever deletes unread notes: the RPC deletes on read, but a note
--    nobody opens lived forever despite the 7-day expires_at.
-- 3. read_and_burn_note ignored expires_at: an unswept note could still be
--    opened after its advertised expiry.

-- 1. Cap ciphertext size (existing rows verified far below the cap).
ALTER TABLE public.burn_notes
  ADD CONSTRAINT burn_notes_ciphertext_size
  CHECK (length(ciphertext) <= 100000);

-- 2. Honor expiry at read time: expired notes return NULL ("already burned,
--    read, or expired") instead of their content.
CREATE OR REPLACE FUNCTION public.read_and_burn_note(note_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  retrieved_ciphertext TEXT;
BEGIN
  DELETE FROM public.burn_notes
  WHERE id = note_id
    AND expires_at > now()
  RETURNING ciphertext INTO retrieved_ciphertext;

  RETURN retrieved_ciphertext;
END;
$$;

-- 3. Hourly sweep of expired rows via pg_cron (available on Supabase).
--    cron.schedule upserts by job name, so re-running is safe.
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule(
  'burn-notes-expiry-sweep',
  '17 * * * *',
  $$DELETE FROM public.burn_notes WHERE expires_at < now()$$
);
