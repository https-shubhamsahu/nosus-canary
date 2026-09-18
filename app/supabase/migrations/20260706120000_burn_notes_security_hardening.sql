-- Migration: 20260706120000_burn_notes_security_hardening.sql
-- Fixes a critical hole in burn_notes: the "Anyone can read/delete" RLS
-- policies let any anonymous client hit PostgREST directly
-- (GET/DELETE /rest/v1/burn_notes) and read or destroy every secret,
-- bypassing the burn-on-read RPC entirely. Only the RPC (SECURITY DEFINER,
-- which bypasses RLS as the function owner) should ever read/delete rows.
-- Insert stays open: anonymous senders must be able to create notes.

DROP POLICY IF EXISTS "Anyone can read burn notes" ON public.burn_notes;
DROP POLICY IF EXISTS "Anyone can delete burn notes" ON public.burn_notes;

-- Atomic burn-on-read: single DELETE...RETURNING instead of SELECT-then-DELETE,
-- which had a race window letting two concurrent readers both retrieve the
-- ciphertext before either delete landed. Also pins search_path per the
-- Supabase security linter (function_search_path_mutable).
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
  RETURNING ciphertext INTO retrieved_ciphertext;

  RETURN retrieved_ciphertext;
END;
$$;

ALTER FUNCTION public.is_admin(uuid) SET search_path = public;
ALTER FUNCTION public.is_super_admin(uuid) SET search_path = public;
ALTER FUNCTION public.handle_user_role_setup() SET search_path = public;
ALTER FUNCTION public.revoke_device(uuid) SET search_path = public;
ALTER FUNCTION public.update_study_group_file_count() SET search_path = public;
