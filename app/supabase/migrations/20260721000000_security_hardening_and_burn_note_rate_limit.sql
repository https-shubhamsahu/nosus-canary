-- Security hardening + RLS performance consolidation
--
-- Follow-up to the audit in Pass 2 of the production-readiness review.
-- Every change here is additive-safe or a straight tightening — nothing
-- edits data destructively.

-- ===========================================================================
-- 1. study_groups.invite_code: close the direct-insert / collision gap
-- ===========================================================================
ALTER TABLE public.study_groups
  ADD CONSTRAINT study_groups_invite_code_key UNIQUE (invite_code);

DROP POLICY IF EXISTS "groups: authenticated insert" ON public.study_groups;

-- ===========================================================================
-- 2. pg_net-in-public advisory: deliberately NOT fixed here (see report —
-- ALTER EXTENSION SET SCHEMA is unsupported for pg_net; drop+recreate is
-- too high-blast-radius for an automated pass).
-- ===========================================================================

-- ===========================================================================
-- 3. Burn Notes: lightweight global insert-velocity guard
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.burn_note_velocity (
  bucket_start timestamptz PRIMARY KEY,
  insert_count integer NOT NULL DEFAULT 0
);

ALTER TABLE public.burn_note_velocity ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.check_burn_note_velocity()
RETURNS trigger AS $$
DECLARE
  v_bucket timestamptz := date_trunc('minute', now());
  v_count integer;
BEGIN
  INSERT INTO public.burn_note_velocity (bucket_start, insert_count)
  VALUES (v_bucket, 1)
  ON CONFLICT (bucket_start) DO UPDATE SET insert_count = burn_note_velocity.insert_count + 1
  RETURNING insert_count INTO v_count;

  DELETE FROM public.burn_note_velocity WHERE bucket_start < v_bucket - interval '10 minutes';

  IF v_count > 120 THEN
    RAISE EXCEPTION 'Too many burn notes created right now. Please try again in a moment.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE EXECUTE ON FUNCTION public.check_burn_note_velocity() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS burn_notes_velocity_guard ON public.burn_notes;
CREATE TRIGGER burn_notes_velocity_guard
  BEFORE INSERT ON public.burn_notes
  FOR EACH ROW EXECUTE FUNCTION public.check_burn_note_velocity();

-- ===========================================================================
-- 4. Consolidate multiple permissive RLS policies (performance advisory)
-- ===========================================================================
DROP POLICY IF EXISTS feature_flags_write_admin ON public.feature_flags;
CREATE POLICY feature_flags_write_insert ON public.feature_flags
  FOR INSERT TO authenticated WITH CHECK (is_admin((SELECT auth.uid())));
CREATE POLICY feature_flags_write_update ON public.feature_flags
  FOR UPDATE TO authenticated USING (is_admin((SELECT auth.uid()))) WITH CHECK (is_admin((SELECT auth.uid())));
CREATE POLICY feature_flags_write_delete ON public.feature_flags
  FOR DELETE TO authenticated USING (is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS remote_configs_select_authenticated ON public.remote_configs;
DROP POLICY IF EXISTS remote_configs_write_admin ON public.remote_configs;
CREATE POLICY remote_configs_write_insert ON public.remote_configs
  FOR INSERT TO authenticated WITH CHECK (is_admin((SELECT auth.uid())));
CREATE POLICY remote_configs_write_update ON public.remote_configs
  FOR UPDATE TO authenticated USING (is_admin((SELECT auth.uid()))) WITH CHECK (is_admin((SELECT auth.uid())));
CREATE POLICY remote_configs_write_delete ON public.remote_configs
  FOR DELETE TO authenticated USING (is_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS group_invites_write_members ON public.group_invites;
CREATE POLICY group_invites_write_insert ON public.group_invites
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM public.study_group_members
            WHERE study_group_members.group_id = group_invites.group_id
              AND study_group_members.user_id = (SELECT auth.uid()))
  );
CREATE POLICY group_invites_write_update ON public.group_invites
  FOR UPDATE TO authenticated USING (
    EXISTS (SELECT 1 FROM public.study_group_members
            WHERE study_group_members.group_id = group_invites.group_id
              AND study_group_members.user_id = (SELECT auth.uid()))
  );
CREATE POLICY group_invites_write_delete ON public.group_invites
  FOR DELETE TO authenticated USING (
    EXISTS (SELECT 1 FROM public.study_group_members
            WHERE study_group_members.group_id = group_invites.group_id
              AND study_group_members.user_id = (SELECT auth.uid()))
  );

DROP POLICY IF EXISTS user_roles_write_super ON public.user_roles;
CREATE POLICY user_roles_write_insert ON public.user_roles
  FOR INSERT TO authenticated WITH CHECK (is_super_admin((SELECT auth.uid())));
CREATE POLICY user_roles_write_update ON public.user_roles
  FOR UPDATE TO authenticated USING (is_super_admin((SELECT auth.uid()))) WITH CHECK (is_super_admin((SELECT auth.uid())));
CREATE POLICY user_roles_write_delete ON public.user_roles
  FOR DELETE TO authenticated USING (is_super_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS "members: admin delete" ON public.study_group_members;
DROP POLICY IF EXISTS "members: self delete" ON public.study_group_members;
CREATE POLICY "members: admin or self delete" ON public.study_group_members
  FOR DELETE TO authenticated
  USING (is_group_admin(group_id) OR user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "groups: invite code lookup" ON public.study_groups;
DROP POLICY IF EXISTS "groups: member select" ON public.study_groups;
CREATE POLICY "groups: invite code or member select" ON public.study_groups
  FOR SELECT TO authenticated
  USING (invite_code IS NOT NULL OR is_group_member(id));
