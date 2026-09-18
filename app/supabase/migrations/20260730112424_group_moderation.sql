-- Community administration: roles, removals and bans as audited operations.
--
-- Before this, the only moderation the product had was a direct
-- `DELETE FROM study_group_members` from the client, permitted by the
-- "members: admin or self delete" policy. That worked, but:
--
--   * it wrote nothing to the audit ledger, so the one action an admin can take
--     against another person was the one action the group could not see;
--   * there was no way to change a role, despite `is_admin` existing and the
--     "members: admin update" policy already allowing it;
--   * there was no way to stop a removed person simply re-using the invite;
--   * an admin could remove or demote the last admin and strand the group.
--
-- Everything below routes through SECURITY DEFINER RPCs that re-check
-- authorisation server-side and write the audit entry in the same transaction,
-- so a moderation action and its record cannot come apart.

-- ===========================================================================
-- 1. New audit vocabulary
-- ===========================================================================
-- audit_logs.event_type is CHECK-constrained, so new events must be declared.
--
-- This also repairs three event types the app has been *emitting* since
-- 20260710010000 but which the constraint never accepted: overlay_detected,
-- accessibility_detected and display_mirroring_detected. AuditService lists all
-- three as allowed and ScreenshotGuard._logOverlayDetected fires the first one
-- for real, but every such INSERT was rejected by this constraint and swallowed
-- by SupabaseService.logEvent's catch block. Three shipped detectors have been
-- writing to nothing.
ALTER TABLE public.audit_logs DROP CONSTRAINT IF EXISTS chk_audit_event_type;
ALTER TABLE public.audit_logs ADD CONSTRAINT chk_audit_event_type CHECK (
  event_type IN (
    'file_uploaded',
    'file_downloaded',
    'file_viewed',
    'file_deleted',
    'file_renamed',
    'file_pinned',
    'member_joined',
    'member_left',
    'member_removed',
    'member_banned',
    'member_unbanned',
    'member_promoted',
    'member_demoted',
    'group_created',
    'group_updated',
    'invite_generated',
    'invite_used',
    'screenshot_attempt',
    'recording_attempt',
    'unauthorized_access',
    'overlay_detected',
    'accessibility_detected',
    'display_mirroring_detected'
  )
);

-- ===========================================================================
-- 2. Bans
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.group_bans (
  group_id text NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  -- SET NULL rather than CASCADE: an admin deleting their own account must not
  -- silently lift every ban they issued.
  banned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id),
  CONSTRAINT group_bans_reason_len CHECK (reason IS NULL OR length(reason) <= 280)
);

CREATE INDEX IF NOT EXISTS idx_group_bans_user ON public.group_bans(user_id);

ALTER TABLE public.group_bans ENABLE ROW LEVEL SECURITY;

-- Members can see who is banned from their own group — same reasoning as the
-- audit log being group-visible: moderation that only moderators can see is not
-- accountable. Writes are RPC-only (no INSERT/UPDATE/DELETE policy exists), so
-- a client cannot ban anyone by talking to the table directly.
CREATE POLICY "bans: group member select" ON public.group_bans
  FOR SELECT TO authenticated
  USING (public.is_group_member(group_id));

CREATE OR REPLACE FUNCTION public.is_group_banned(p_group_id text, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_bans
    WHERE group_id = p_group_id AND user_id = p_user_id
  );
$$;

REVOKE EXECUTE ON FUNCTION public.is_group_banned(text, uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_group_banned(text, uuid) TO authenticated;

-- ===========================================================================
-- 3. Shared guards
-- ===========================================================================
-- Every mutating RPC below begins with these two checks, so the rules live in
-- one place rather than being re-typed (and eventually mis-typed) five times.
CREATE OR REPLACE FUNCTION public.assert_group_admin(p_group_id text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_group_admin(p_group_id) THEN
    RAISE EXCEPTION 'Only a group admin can do that' USING ERRCODE = '42501';
  END IF;
  RETURN v_actor;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.assert_group_admin(text) FROM public, anon, authenticated;

-- Refuses to leave a group with no admin. Guards both demotion and removal,
-- because either can be the action that orphans the group.
CREATE OR REPLACE FUNCTION public.assert_not_last_admin(p_group_id text, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_count integer;
BEGIN
  SELECT count(*) INTO v_admin_count
  FROM public.study_group_members
  WHERE group_id = p_group_id AND is_admin = true;

  IF v_admin_count <= 1 AND EXISTS (
    SELECT 1 FROM public.study_group_members
    WHERE group_id = p_group_id AND user_id = p_user_id AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'This is the last admin. Promote someone else first.'
      USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.assert_not_last_admin(text, uuid) FROM public, anon, authenticated;

-- Display name for audit metadata. Reads profiles as definer so the entry is
-- readable even to members who could not otherwise see that profile row.
CREATE OR REPLACE FUNCTION public.group_member_label(p_user_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    NULLIF(btrim(p.display_name), ''),
    split_part(p.email, '@', 1),
    'A member'
  )
  FROM public.profiles p
  WHERE p.id = p_user_id;
$$;

REVOKE EXECUTE ON FUNCTION public.group_member_label(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.group_member_label(uuid) TO authenticated;

-- ===========================================================================
-- 4. Moderation RPCs
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.set_group_member_role(
  p_group_id text,
  p_user_id uuid,
  p_is_admin boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_actor uuid;
  v_current boolean;
BEGIN
  v_actor := public.assert_group_admin(p_group_id);

  SELECT is_admin INTO v_current
  FROM public.study_group_members
  WHERE group_id = p_group_id AND user_id = p_user_id;

  IF v_current IS NULL THEN
    RAISE EXCEPTION 'That person is not a member of this group' USING ERRCODE = 'P0002';
  END IF;
  IF v_current = p_is_admin THEN
    RETURN; -- idempotent: double-tap or a stale UI, not an error
  END IF;
  IF NOT p_is_admin THEN
    PERFORM public.assert_not_last_admin(p_group_id, p_user_id);
  END IF;

  UPDATE public.study_group_members
  SET is_admin = p_is_admin
  WHERE group_id = p_group_id AND user_id = p_user_id;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (
    p_group_id,
    v_actor,
    NULL,
    CASE WHEN p_is_admin THEN 'member_promoted' ELSE 'member_demoted' END,
    jsonb_build_object('member_name', public.group_member_label(p_user_id))
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_group_member(
  p_group_id text,
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_actor uuid;
  v_label text;
BEGIN
  v_actor := public.assert_group_admin(p_group_id);

  IF p_user_id = v_actor THEN
    -- Leaving is a different operation with different rules (and is allowed by
    -- the "members: admin or self delete" policy). Routing it through the
    -- moderation RPC would log an admin as having removed themselves.
    RAISE EXCEPTION 'Use Leave group to remove yourself' USING ERRCODE = 'P0001';
  END IF;

  PERFORM public.assert_not_last_admin(p_group_id, p_user_id);
  v_label := public.group_member_label(p_user_id);

  DELETE FROM public.study_group_members
  WHERE group_id = p_group_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That person is not a member of this group' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (
    p_group_id, v_actor, NULL, 'member_removed',
    jsonb_build_object('member_name', v_label)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.ban_group_member(
  p_group_id text,
  p_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_actor uuid;
  v_label text;
BEGIN
  v_actor := public.assert_group_admin(p_group_id);

  IF p_user_id = v_actor THEN
    RAISE EXCEPTION 'You cannot ban yourself' USING ERRCODE = 'P0001';
  END IF;

  PERFORM public.assert_not_last_admin(p_group_id, p_user_id);
  v_label := public.group_member_label(p_user_id);

  -- Ban first, then remove: if the delete failed after the ban we would have a
  -- banned member, which the next join attempt corrects. The reverse order
  -- could leave someone removed but free to walk straight back in.
  INSERT INTO public.group_bans (group_id, user_id, banned_by, reason)
  VALUES (p_group_id, p_user_id, v_actor, NULLIF(btrim(p_reason), ''))
  ON CONFLICT (group_id, user_id) DO UPDATE
    SET banned_by = EXCLUDED.banned_by,
        reason = EXCLUDED.reason,
        created_at = now();

  DELETE FROM public.study_group_members
  WHERE group_id = p_group_id AND user_id = p_user_id;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (
    p_group_id, v_actor, NULL, 'member_banned',
    jsonb_build_object('member_name', v_label)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.unban_group_member(
  p_group_id text,
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_actor uuid;
  v_label text;
BEGIN
  v_actor := public.assert_group_admin(p_group_id);
  v_label := public.group_member_label(p_user_id);

  DELETE FROM public.group_bans
  WHERE group_id = p_group_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN; -- already unbanned; nothing happened, so log nothing
  END IF;

  -- Unbanning restores eligibility, not membership. Silently re-adding someone
  -- to a group they were thrown out of is not a decision an admin asked for.
  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (
    p_group_id, v_actor, NULL, 'member_unbanned',
    jsonb_build_object('member_name', v_label)
  );
END;
$$;

-- ===========================================================================
-- 5. Bans are enforced on every join path
-- ===========================================================================
-- A ban that only the UI respects is not a ban. Each join RPC is redefined to
-- check group_bans; the rest of each body is unchanged from its current
-- definition.
CREATE OR REPLACE FUNCTION public.join_group_by_invite_code(p_invite_code text)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_group_id text;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id INTO v_group_id
  FROM public.study_groups
  WHERE invite_code = p_invite_code;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  IF public.is_group_banned(v_group_id, v_user_id) THEN
    RAISE EXCEPTION 'You can no longer join this group' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.study_group_members (group_id, user_id, is_admin)
  VALUES (v_group_id, v_user_id, false)
  ON CONFLICT (group_id, user_id) DO NOTHING;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (v_group_id, v_user_id, NULL, 'member_joined', '{}'::jsonb);

  RETURN v_group_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.join_public_group_by_name(p_group_name text)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_group_id text;
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT id INTO v_group_id
  FROM public.study_groups
  WHERE name = p_group_name;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Group not found';
  END IF;

  IF public.is_group_banned(v_group_id, v_user_id) THEN
    RAISE EXCEPTION 'You can no longer join this group' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.study_group_members (group_id, user_id, is_admin)
  VALUES (v_group_id, v_user_id, false)
  ON CONFLICT (group_id, user_id) DO NOTHING;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (v_group_id, v_user_id, NULL, 'member_joined', '{}'::jsonb);

  RETURN v_group_id;
END;
$$;

-- join_group_by_invite_link carries invite bookkeeping (revocation, expiry,
-- max_uses, use_count) that must not be duplicated, so this is its existing
-- body with two changes and nothing else. The `FOR UPDATE` row lock is
-- load-bearing — it is what makes the max_uses check safe against two people
-- redeeming the last use of a link simultaneously — and is preserved exactly.
--
-- Change 1: the ban check, on both the group_invites path and the legacy
--           study_groups.invite_code fallback.
-- Change 2: the audit entry no longer carries `invite_code` in its metadata.
--           audit_logs is readable by every member of the group, so writing a
--           live invite code into it let any member harvest working codes for
--           their own group from the activity feed. The member's display name
--           is more useful in the feed anyway.
CREATE OR REPLACE FUNCTION public.join_group_by_invite_link(
  p_invite_code text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_group_id text;
  v_user_id uuid;
  v_invite record;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Fetch and lock invite row
  SELECT * INTO v_invite
  FROM public.group_invites
  WHERE code = p_invite_code FOR UPDATE;

  IF v_invite IS NULL THEN
    -- Fallback to the legacy static invite_code column on study_groups
    SELECT id INTO v_group_id
    FROM public.study_groups
    WHERE invite_code = p_invite_code;

    IF v_group_id IS NULL THEN
      RAISE EXCEPTION 'Invalid invite code or link';
    END IF;

    IF public.is_group_banned(v_group_id, v_user_id) THEN
      RAISE EXCEPTION 'You can no longer join this group' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.study_group_members (group_id, user_id, is_admin)
    VALUES (v_group_id, v_user_id, false)
    ON CONFLICT (group_id, user_id) DO NOTHING;

    INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
    VALUES (v_group_id, v_user_id, NULL, 'member_joined', '{}'::jsonb);

    RETURN v_group_id;
  END IF;

  -- 2. Validate invite constraints
  IF v_invite.is_revoked THEN
    RAISE EXCEPTION 'This invite link has been revoked';
  END IF;

  IF v_invite.expires_at IS NOT NULL AND v_invite.expires_at < now() THEN
    RAISE EXCEPTION 'This invite link has expired';
  END IF;

  IF v_invite.max_uses IS NOT NULL AND v_invite.use_count >= v_invite.max_uses THEN
    RAISE EXCEPTION 'This invite link has reached its usage limit';
  END IF;

  IF public.is_group_banned(v_invite.group_id, v_user_id) THEN
    RAISE EXCEPTION 'You can no longer join this group' USING ERRCODE = '42501';
  END IF;

  -- 3. Add member
  INSERT INTO public.study_group_members (group_id, user_id, is_admin)
  VALUES (v_invite.group_id, v_user_id, false)
  ON CONFLICT (group_id, user_id) DO NOTHING;

  -- 4. Update invite metrics
  UPDATE public.group_invites
  SET use_count = use_count + 1
  WHERE code = p_invite_code;

  -- 5. Log activity
  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (v_invite.group_id, v_user_id, NULL, 'member_joined',
          jsonb_build_object('member_name', public.group_member_label(v_user_id)));

  RETURN v_invite.group_id;
END;
$$;

-- ===========================================================================
-- 6. Grants
-- ===========================================================================
REVOKE EXECUTE ON FUNCTION public.set_group_member_role(text, uuid, boolean) FROM public, anon;
REVOKE EXECUTE ON FUNCTION public.remove_group_member(text, uuid) FROM public, anon;
REVOKE EXECUTE ON FUNCTION public.ban_group_member(text, uuid, text) FROM public, anon;
REVOKE EXECUTE ON FUNCTION public.unban_group_member(text, uuid) FROM public, anon;

GRANT EXECUTE ON FUNCTION public.set_group_member_role(text, uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_group_member(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ban_group_member(text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unban_group_member(text, uuid) TO authenticated;
