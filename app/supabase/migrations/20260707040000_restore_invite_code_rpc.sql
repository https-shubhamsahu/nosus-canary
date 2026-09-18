-- Migration: 20260707040000_restore_invite_code_rpc.sql
-- Same bug class as 20260707030000: join_group_by_invite_code exists in the
-- repo's baseline.sql but was never applied to the live project, so the
-- entire invite-code join flow failed with PGRST202. Copied verbatim from
-- 20260629000000_baseline.sql.

CREATE OR REPLACE FUNCTION public.join_group_by_invite_code(
  p_invite_code text
)
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

  INSERT INTO public.study_group_members (group_id, user_id, is_admin)
  VALUES (v_group_id, v_user_id, false)
  ON CONFLICT (group_id, user_id) DO NOTHING;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (v_group_id, v_user_id, NULL, 'member_joined', '{}'::jsonb);

  RETURN v_group_id;
END;
$$;
