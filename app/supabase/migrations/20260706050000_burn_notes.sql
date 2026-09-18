-- Migration: 20260706050000_burn_notes.sql
-- Zero-knowledge burn-on-read secrets exchange table
--
-- Only INSERT is open to anonymous clients (senders may have no account).
-- Reads and deletes are never exposed directly to PostgREST — the only way
-- to retrieve (and atomically destroy) a note is the read_and_burn_note RPC
-- below, which runs SECURITY DEFINER and bypasses RLS as the function owner.
-- (An earlier draft of this migration briefly also opened SELECT/DELETE with
-- USING (true), which defeated the burn-on-read guarantee; fixed here so a
-- fresh environment never passes through that insecure intermediate state.)

CREATE TABLE IF NOT EXISTS public.burn_notes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ciphertext   TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at   TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days')
);

-- RLS
ALTER TABLE public.burn_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can insert burn notes" ON public.burn_notes
  FOR INSERT WITH CHECK (true);

-- RPC for atomic read-and-delete (burn on read)
CREATE OR REPLACE FUNCTION read_and_burn_note(note_id UUID)
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
  RETURNING ciphertext INTO retrieved_ciphertext;

  RETURN retrieved_ciphertext;
END;
$$;
