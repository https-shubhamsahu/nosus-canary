-- Close the private-group boundary: membership is granted by RPC, not by the
-- client asserting it.
--
-- Before this migration, two permissive policies combined into a full bypass of
-- the invite system:
--
--   1. "members: self insert" allowed ANY authenticated user to INSERT a
--      study_group_members row for themselves into ANY group — there was no
--      predicate on group_id at all. WITH CHECK (user_id = auth.uid()) only
--      proves you are inserting *yourself*, never that you were *invited*.
--   2. "groups: invite code or member select" allowed ANY authenticated user to
--      SELECT every study_groups row whose invite_code IS NOT NULL — including
--      the invite_code column itself. So the codes protecting every private
--      group were readable by every account in the system.
--
-- Chained: read every invite code (or skip that and just insert yourself by
-- group id), become a member, and "files: member select" then hands over every
-- document in that group. The invite flow was enforced only by the client
-- choosing to call the RPC.
--
-- 20260721000000 already applied exactly this fix to study_groups INSERT
-- (dropping "groups: authenticated insert" so only
-- create_study_group_with_creator can create a group). This finishes the same
-- job for membership.
--
-- No client change is needed: every join path already goes through a
-- SECURITY DEFINER routine, which is not subject to RLS.
--
--   create_study_group_with_creator  (creator becomes admin)
--   join_group_by_invite_code        (legacy static study_groups.invite_code)
--   join_group_by_invite_link        (group_invites, with expiry/use limits)
--   join_public_group_by_name        (Global Community / named communities)
--   handle_new_user                  (signup trigger)
--
-- ===========================================================================
-- 1. Membership is granted server-side only
-- ===========================================================================
DROP POLICY IF EXISTS "members: self insert" ON public.study_group_members;

-- Deliberately NOT replaced with a narrower INSERT policy. There is no
-- client-side insert that should succeed: an "insert myself into a group I can
-- prove I may join" predicate would have to re-implement invite validation
-- (revocation, expiry, max_uses) in a policy expression, where
-- join_group_by_invite_link already does it correctly and atomically.

-- ===========================================================================
-- 2. Stop publishing every private group's invite code
-- ===========================================================================
DROP POLICY IF EXISTS "groups: invite code or member select" ON public.study_groups;

CREATE POLICY "groups: member select" ON public.study_groups
  FOR SELECT TO authenticated
  USING (public.is_group_member(id));

-- Pre-join invite previews are unaffected: get_invite_details() is
-- SECURITY DEFINER and returns only name/description/member count/creator —
-- never the invite_code, and never the group's file list.

-- ===========================================================================
-- 3. profiles: stop exposing the whole user directory
-- ===========================================================================
-- "Users can view their own profile" was USING (true) — despite its name, it
-- let any authenticated user read every profile row (id, email, display_name).
-- Group member lists genuinely need co-members' names, and the super-admin
-- console needs the directory, so scope it to exactly those three cases.
--
-- SECURITY DEFINER helper rather than an inline EXISTS: the subquery would
-- otherwise evaluate study_group_members' own RLS from inside a policy on
-- profiles, on every row of every profile read.
CREATE OR REPLACE FUNCTION public.shares_group_with(p_other_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.study_group_members mine
    JOIN public.study_group_members theirs ON theirs.group_id = mine.group_id
    WHERE mine.user_id = (SELECT auth.uid())
      AND theirs.user_id = p_other_user_id
  );
$$;

REVOKE EXECUTE ON FUNCTION public.shares_group_with(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.shares_group_with(uuid) TO authenticated;

DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;

CREATE POLICY "profiles: self, co-member or admin select" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR public.is_admin((SELECT auth.uid()))
    OR public.shares_group_with(id)
  );

-- Honest scope note: every account is auto-joined to "Global Community" by
-- handle_new_user(), so today shares_group_with() is true for almost every
-- pair of users and this policy blocks little in practice. It is still the
-- correct shape — it stops being a no-op the moment a deployment does not
-- funnel everyone through one universal group, and it costs one indexed
-- lookup. Do not read it as "profiles are private now".

-- ===========================================================================
-- 4. Signup no longer force-joins TSEC
-- ===========================================================================
-- handle_new_user() joined every new account to BOTH 'Global Community' and
-- 'TSEC, Kandivali' unconditionally. Onboarding asks "Are you a student at
-- TSEC, Kandivali?" and joins on yes — but the trigger had already joined
-- them, so the answer was decorative and every user worldwide landed in a
-- single college's group. Global Community stays (it is what a brand-new
-- account has to look at); TSEC becomes opt-in through the same
-- join_public_group_by_name RPC onboarding already calls.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_global_id text;
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;

  SELECT id INTO v_global_id FROM public.study_groups WHERE name = 'Global Community';
  IF v_global_id IS NULL THEN
    v_global_id := '8055b43a-6d07-4588-a39f-159e6154a019';
    INSERT INTO public.study_groups (id, name, description, is_watermark_enabled)
    VALUES (v_global_id, 'Global Community', 'A home for all No Sus users.', true)
    ON CONFLICT (id) DO NOTHING;
  END IF;

  INSERT INTO public.study_group_members (group_id, user_id, is_admin)
  VALUES (v_global_id, NEW.id, false)
  ON CONFLICT (group_id, user_id) DO NOTHING;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (v_global_id, NEW.id, NULL, 'member_joined', '{}'::jsonb)
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$;

-- Existing TSEC memberships are left alone. Removing them would silently drop
-- real students out of a group they are actively using, and any member can
-- leave through the normal "members: admin or self delete" path.
