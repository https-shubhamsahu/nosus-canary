-- Migration: 20260710000000_group_invites.sql
-- Setup table and RPCs for zoom/slack-style dynamic group invites

CREATE TABLE IF NOT EXISTS public.group_invites (
  code          TEXT PRIMARY KEY,
  group_id      TEXT NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
  creator_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ,       -- null means never expires
  max_uses      INTEGER,           -- null means unlimited uses
  use_count     INTEGER NOT NULL DEFAULT 0,
  is_revoked    BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_group_invites_group ON public.group_invites (group_id);

-- Enable RLS
ALTER TABLE public.group_invites ENABLE ROW LEVEL SECURITY;

-- Select policy: Anyone can select (required to show details on web landing / pre-screen)
DROP POLICY IF EXISTS "group_invites_select_public" ON public.group_invites;
CREATE POLICY "group_invites_select_public" ON public.group_invites
  FOR SELECT USING (true);

-- Write policy: Only authenticated group members can create/manage invites
DROP POLICY IF EXISTS "group_invites_write_members" ON public.group_invites;
CREATE POLICY "group_invites_write_members" ON public.group_invites
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.study_group_members
      WHERE group_id = group_invites.group_id
        AND user_id = auth.uid()
    )
  );

-- RPC for previewing invite details safely
CREATE OR REPLACE FUNCTION public.get_invite_details(
  p_invite_code text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_group_id text;
  v_group_name text;
  v_group_desc text;
  v_member_count bigint;
  v_creator_name text;
  v_invite record;
BEGIN
  -- 1. Look up in group_invites
  SELECT * INTO v_invite
  FROM public.group_invites
  WHERE code = p_invite_code;

  IF v_invite IS NOT NULL THEN
    -- Validate constraints
    IF v_invite.is_revoked THEN
      RETURN jsonb_build_object('valid', false, 'reason', 'This invite link has been revoked');
    END IF;
    IF v_invite.expires_at IS NOT NULL AND v_invite.expires_at < now() THEN
      RETURN jsonb_build_object('valid', false, 'reason', 'This invite link has expired');
    END IF;
    IF v_invite.max_uses IS NOT NULL AND v_invite.use_count >= v_invite.max_uses THEN
      RETURN jsonb_build_object('valid', false, 'reason', 'This invite link has reached its usage limit');
    END IF;

    v_group_id := v_invite.group_id;
    
    -- Fetch creator display name
    SELECT display_name INTO v_creator_name
    FROM public.profiles
    WHERE id = v_invite.creator_id;
  ELSE
    -- Check legacy static code
    SELECT id INTO v_group_id
    FROM public.study_groups
    WHERE invite_code = p_invite_code;
    
    IF v_group_id IS NULL THEN
      RETURN jsonb_build_object('valid', false, 'reason', 'Invalid invite code or link');
    END IF;
    
    v_creator_name := 'Admin';
  END IF;

  -- 2. Fetch group details
  SELECT name, description INTO v_group_name, v_group_desc
  FROM public.study_groups
  WHERE id = v_group_id;

  SELECT count(*) INTO v_member_count
  FROM public.study_group_members
  WHERE group_id = v_group_id;

  RETURN jsonb_build_object(
    'valid', true,
    'group_id', v_group_id,
    'group_name', v_group_name,
    'group_description', COALESCE(v_group_desc, ''),
    'member_count', v_member_count,
    'creator_name', COALESCE(v_creator_name, 'Group Administrator')
  );
END;
$$;

-- RPC for joining a group via invite link safely
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
  VALUES (v_invite.group_id, v_user_id, NULL, 'member_joined', jsonb_build_object('invite_code', p_invite_code));

  RETURN v_invite.group_id;
END;
$$;

-- Insert app_download_url remote config if not already present
INSERT INTO public.remote_configs (config_key, config_value, description)
VALUES (
  'app_download_url',
  '"https://https-shubhamsahu.github.io/NON_SUS/app-release.apk"',
  'Mobile app download destination URL'
) ON CONFLICT (config_key) DO NOTHING;

-- Grant select to public (anon/authenticated) on remote_configs
DROP POLICY IF EXISTS "remote_configs_select_anon" ON public.remote_configs;
CREATE POLICY "remote_configs_select_anon" ON public.remote_configs
  FOR SELECT USING (true);
