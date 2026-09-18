-- =============================================================================
-- NO SUS — CONSOLIDATED BASELINE SCHEMA MIGRATION
-- =============================================================================

-- ─── EXTENSIONS ──────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- SECTION 1: DATABASE TABLES
-- =============================================================================

-- 1. PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text UNIQUE,
    display_name text,
    avatar_color_start text DEFAULT 'FF0072FF',
    avatar_color_end text DEFAULT 'FF00F2FE',
    onboarding_completed boolean DEFAULT false,
    avatar_id integer DEFAULT 0,
    survey_goals text[],
    survey_features text[],
    survey_user_type text,
    updated_at timestamptz DEFAULT now()
);

-- 2. STUDY GROUPS
CREATE TABLE IF NOT EXISTS public.study_groups (
    id text PRIMARY KEY,
    name text NOT NULL,
    description text,
    is_watermark_enabled boolean NOT NULL DEFAULT true,
    invite_code text,
    file_count integer NOT NULL DEFAULT 0,
    last_activity timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now()
);

-- 3. STUDY GROUP MEMBERS
CREATE TABLE IF NOT EXISTS public.study_group_members (
    group_id text REFERENCES public.study_groups(id) ON DELETE CASCADE,
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_admin boolean NOT NULL DEFAULT false,
    joined_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (group_id, user_id)
);

-- 4. SECURE FILES
CREATE TABLE IF NOT EXISTS public.secure_files (
    id text PRIMARY KEY,
    group_id text NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    name text NOT NULL,
    type text NOT NULL DEFAULT 'pdf',
    size_bytes integer NOT NULL DEFAULT 0,
    is_watermarked boolean DEFAULT true,
    is_pinned boolean DEFAULT false,
    security_status text DEFAULT 'secured',
    uploaded_at timestamptz NOT NULL DEFAULT now(),
    storage_path text,
    gdrive_file_id text,
    key_id text,
    uploaded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    CONSTRAINT secure_files_security_status_check CHECK (security_status IN ('secured', 'pending', 'compromised', 'revoked'))
);

-- 5. AUDIT LOGS
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id text NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    file_id text REFERENCES public.secure_files(id) ON DELETE SET NULL,
    event_type text NOT NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    previous_hash text NOT NULL,
    entry_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_audit_metadata_object CHECK (jsonb_typeof(metadata) = 'object'),
    CONSTRAINT chk_audit_event_type CHECK (
        event_type IN (
            'file_uploaded',
            'file_downloaded',
            'file_viewed',
            'file_deleted',
            'file_renamed',
            'file_pinned',
            'member_joined',
            'member_left',
            'member_promoted',
            'member_demoted',
            'group_created',
            'group_updated',
            'invite_generated',
            'invite_used',
            'screenshot_attempt',
            'recording_attempt',
            'unauthorized_access'
        )
    )
);

-- Indexes for Audit Logs
CREATE INDEX IF NOT EXISTS idx_audit_group_created ON public.audit_logs(group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON public.audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_file ON public.audit_logs(file_id);

-- Performance and RLS Indexes
CREATE INDEX IF NOT EXISTS idx_secure_files_group_id ON public.secure_files(group_id);
CREATE INDEX IF NOT EXISTS idx_secure_files_owner_id ON public.secure_files(owner_id);
CREATE INDEX IF NOT EXISTS idx_secure_files_uploaded_at ON public.secure_files(uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_study_group_members_user_id ON public.study_group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_study_groups_invite_code ON public.study_groups(invite_code) WHERE invite_code IS NOT NULL;

-- 6. FOCUS LOGS
CREATE TABLE IF NOT EXISTS public.focus_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date date NOT NULL,
    focus_minutes integer NOT NULL DEFAULT 0,
    UNIQUE (user_id, date)
);

-- 7. USER NOTES
CREATE TABLE IF NOT EXISTS public.user_notes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    note_text text NOT NULL DEFAULT '',
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- SECTION 2: SECURITY DEFINER HELPERS & RPCs
-- =============================================================================

-- 1. GROUP MEMBERSHIP QUERY BYPASS
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.study_group_members
    WHERE group_id = p_group_id AND user_id = auth.uid()
  );
END;
$$;

-- 2. GROUP ADMIN QUERY BYPASS
CREATE OR REPLACE FUNCTION public.is_group_admin(p_group_id text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.study_group_members
    WHERE group_id = p_group_id AND user_id = auth.uid() AND is_admin = true
  );
END;
$$;

-- 3. SIGNUP AUTH AUTOMATION
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_global_id text;
  v_tsec_id text;
BEGIN
  -- 1. Insert Profile
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;

  -- 2. Ensure Global Community group exists and get its ID
  SELECT id INTO v_global_id FROM public.study_groups WHERE name = 'Global Community';
  IF v_global_id IS NULL THEN
    v_global_id := '8055b43a-6d07-4588-a39f-159e6154a019';
    INSERT INTO public.study_groups (id, name, description, is_watermark_enabled)
    VALUES (v_global_id, 'Global Community', 'A home for all No Sus users.', true)
    ON CONFLICT (id) DO NOTHING;
  END IF;

  -- 3. Ensure TSEC, Kandivali group exists and get its ID
  SELECT id INTO v_tsec_id FROM public.study_groups WHERE name = 'TSEC, Kandivali';
  IF v_tsec_id IS NULL THEN
    v_tsec_id := '12792cd4-9f89-4331-a4af-1b86a72f8f47';
    INSERT INTO public.study_groups (id, name, description, is_watermark_enabled)
    VALUES (v_tsec_id, 'TSEC, Kandivali', 'TSEC Kandivali Students Community', true)
    ON CONFLICT (id) DO NOTHING;
  END IF;

  -- 4. Auto-join user to both groups
  INSERT INTO public.study_group_members (group_id, user_id, is_admin)
  VALUES 
    (v_global_id, NEW.id, false),
    (v_tsec_id, NEW.id, false)
  ON CONFLICT (group_id, user_id) DO NOTHING;

  -- 5. Write audit logs for these joins
  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES 
    (v_global_id, NEW.id, NULL, 'member_joined', '{}'::jsonb),
    (v_tsec_id, NEW.id, NULL, 'member_joined', '{}'::jsonb)
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. FILE COUNT SYNCHRONIZATION
CREATE OR REPLACE FUNCTION public.update_study_group_file_count()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.study_groups
        SET file_count = file_count + 1
        WHERE id = NEW.group_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.study_groups
        SET file_count = file_count - 1
        WHERE id = OLD.group_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_study_group_file_count ON public.secure_files;
CREATE TRIGGER trg_update_study_group_file_count
  AFTER INSERT OR DELETE ON public.secure_files
  FOR EACH ROW EXECUTE FUNCTION public.update_study_group_file_count();

-- 5. AUDIT CHAIN HASH TRIGGERS
CREATE OR REPLACE FUNCTION public.audit_logs_hash_trigger()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  prev_hash text;
BEGIN
  SELECT entry_hash INTO prev_hash
  FROM public.audit_logs
  WHERE group_id = NEW.group_id AND id != NEW.id
  ORDER BY created_at DESC, id DESC
  LIMIT 1;

  NEW.previous_hash := COALESCE(prev_hash, 'GENESIS');

  NEW.entry_hash := encode(digest(
    NEW.actor_id::text || NEW.event_type || NEW.created_at::text || NEW.previous_hash,
    'sha256'
  ), 'hex');

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_logs_hash ON public.audit_logs;
CREATE TRIGGER trg_audit_logs_hash
  BEFORE INSERT ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.audit_logs_hash_trigger();

-- 6. RPC: VERIFY LEDGER TIMELINE
CREATE OR REPLACE FUNCTION public.verify_audit_chain(p_group_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  rec record;
  computed_hash text;
  expected_prev text := 'GENESIS';
BEGIN
  FOR rec IN
    SELECT * FROM public.audit_logs
    WHERE group_id = p_group_id
    ORDER BY created_at ASC, id ASC
  LOOP
    IF rec.previous_hash IS DISTINCT FROM expected_prev THEN
      RETURN jsonb_build_object('status', 'invalid', 'first_broken_record', rec.id, 'reason', 'previous_hash mismatch');
    END IF;

    computed_hash := encode(digest(
      rec.actor_id::text || rec.event_type || rec.created_at::text || rec.previous_hash,
      'sha256'
    ), 'hex');

    IF rec.entry_hash IS DISTINCT FROM computed_hash THEN
      RETURN jsonb_build_object('status', 'invalid', 'first_broken_record', rec.id, 'reason', 'entry_hash mismatch');
    END IF;

    expected_prev := rec.entry_hash;
  END LOOP;

  RETURN jsonb_build_object('status', 'valid');
END;
$$;

-- 7. RPC: LOG SECURITY EVENTS
CREATE OR REPLACE FUNCTION public.log_group_event(
  p_group_id text,
  p_file_id  text,
  p_event_type text,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT public.is_group_member(p_group_id) THEN
    RAISE EXCEPTION 'Not a member of the study group';
  END IF;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (p_group_id, auth.uid(), p_file_id, p_event_type, p_metadata);

  RETURN true;
END;
$$;

-- 8. RPC: ATOMIC GROUP CREATION
CREATE OR REPLACE FUNCTION public.create_study_group_with_creator(
  p_group_id text,
  p_name text,
  p_description text,
  p_is_watermark_enabled boolean,
  p_invite_code text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.study_groups (id, name, description, is_watermark_enabled, invite_code)
  VALUES (p_group_id, p_name, p_description, p_is_watermark_enabled, p_invite_code);

  INSERT INTO public.study_group_members (group_id, user_id, is_admin)
  VALUES (p_group_id, v_user_id, true)
  ON CONFLICT (group_id, user_id) DO NOTHING;

  PERFORM public.log_group_event(
    p_group_id,
    NULL,
    'group_created',
    jsonb_build_object('group_name', p_name)
  );

  RETURN p_group_id;
END;
$$;

-- 9. RPC: ATOMIC INVITE CODE JOIN
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

-- 10. RPC: ATOMIC COMMUNITY JOIN
CREATE OR REPLACE FUNCTION public.join_public_group_by_name(
  p_group_name text
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
  WHERE name = p_group_name;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Group not found';
  END IF;

  INSERT INTO public.study_group_members (group_id, user_id, is_admin)
  VALUES (v_group_id, v_user_id, false)
  ON CONFLICT (group_id, user_id) DO NOTHING;

  INSERT INTO public.audit_logs (group_id, actor_id, file_id, event_type, metadata)
  VALUES (v_group_id, v_user_id, NULL, 'member_joined', '{}'::jsonb);

  RETURN v_group_id;
END;
$$;

-- 11. RPC: COMMUNITY ASSURANCE
CREATE OR REPLACE FUNCTION public.ensure_community_exists(
  p_name text,
  p_description text
)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_group_id text;
BEGIN
  SELECT id INTO v_group_id
  FROM public.study_groups
  WHERE name = p_name;

  IF v_group_id IS NULL THEN
    v_group_id := gen_random_uuid()::text;
    INSERT INTO public.study_groups (id, name, description, is_watermark_enabled)
    VALUES (v_group_id, p_name, p_description, true);
  END IF;

  RETURN v_group_id;
END;
$$;

-- 12. RPC: STORAGE ACCESS AUTHORIZATION BYPASS
CREATE OR REPLACE FUNCTION public.can_access_storage_object(
  p_bucket_id text,
  p_object_name text,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_bucket_id != 'secure-files' THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.secure_files sf
    JOIN public.study_group_members sgm ON sgm.group_id = sf.group_id
    WHERE (sf.storage_path = p_object_name OR sf.id = p_object_name)
      AND sgm.user_id = p_user_id
  );
END;
$$;

-- 13. RPC: STORAGE DELETE AUTHORIZATION BYPASS
CREATE OR REPLACE FUNCTION public.can_delete_storage_object(
  p_bucket_id text,
  p_object_name text,
  p_user_id uuid,
  p_owner_id text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_bucket_id != 'secure-files' THEN
    RETURN false;
  END IF;

  -- Owner can delete
  IF p_user_id::text = p_owner_id THEN
    RETURN true;
  END IF;

  -- Group admin can delete
  RETURN EXISTS (
    SELECT 1
    FROM public.secure_files sf
    JOIN public.study_group_members sgm ON sgm.group_id = sf.group_id
    WHERE (sf.storage_path = p_object_name OR sf.id = p_object_name)
      AND sgm.user_id = p_user_id
      AND sgm.is_admin = true
  );
END;
$$;

-- =============================================================================
-- SECTION 3: ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================================================

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.secure_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.focus_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;

-- 1. PROFILES POLICIES
CREATE POLICY "Users can view their own profile"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- 2. STUDY GROUPS POLICIES
CREATE POLICY "groups: member select"
  ON public.study_groups FOR SELECT
  TO authenticated
  USING (public.is_group_member(id));

CREATE POLICY "groups: invite code lookup"
  ON public.study_groups FOR SELECT
  TO authenticated
  USING (invite_code IS NOT NULL);

CREATE POLICY "groups: authenticated insert"
  ON public.study_groups FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "groups: admin update"
  ON public.study_groups FOR UPDATE
  TO authenticated
  USING (public.is_group_admin(id));

CREATE POLICY "groups: admin delete"
  ON public.study_groups FOR DELETE
  TO authenticated
  USING (public.is_group_admin(id));

-- 3. STUDY GROUP MEMBERS POLICIES
CREATE POLICY "members: group member select"
  ON public.study_group_members FOR SELECT
  TO authenticated
  USING (public.is_group_member(group_id));

CREATE POLICY "members: self insert"
  ON public.study_group_members FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "members: admin update"
  ON public.study_group_members FOR UPDATE
  TO authenticated
  USING (public.is_group_admin(group_id))
  WITH CHECK (public.is_group_admin(group_id));

CREATE POLICY "members: admin delete"
  ON public.study_group_members FOR DELETE
  TO authenticated
  USING (public.is_group_admin(group_id));

CREATE POLICY "members: self delete"
  ON public.study_group_members FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- 4. SECURE FILES POLICIES
CREATE POLICY "files: member select"
  ON public.secure_files FOR SELECT
  TO authenticated
  USING (public.is_group_member(group_id));

CREATE POLICY "files: member insert"
  ON public.secure_files FOR INSERT
  TO authenticated
  WITH CHECK (public.is_group_member(group_id));

CREATE POLICY "files: owner or admin update"
  ON public.secure_files FOR UPDATE
  TO authenticated
  USING (owner_id = auth.uid() OR public.is_group_admin(group_id));

CREATE POLICY "files: owner or admin delete"
  ON public.secure_files FOR DELETE
  TO authenticated
  USING (owner_id = auth.uid() OR public.is_group_admin(group_id));

-- 5. AUDIT LOGS POLICIES
CREATE POLICY "audit: member select"
  ON public.audit_logs FOR SELECT
  TO authenticated
  USING (public.is_group_member(group_id));

-- 6. FOCUS LOGS POLICIES
CREATE POLICY "focus: self all"
  ON public.focus_logs FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 7. USER NOTES POLICIES
CREATE POLICY "notes: self all"
  ON public.user_notes FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- =============================================================================
-- SECTION 4: STORAGE CONFIGURATIONS & POLICIES
-- =============================================================================

-- Create private bucket 'secure-files'
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'secure-files', 
  'secure-files', 
  false, 
  26214400, 
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/octet-stream']
)
ON CONFLICT (id) DO UPDATE
SET file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Policies on storage.objects
CREATE POLICY "secure-files: group member download"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'secure-files'
    AND public.can_access_storage_object(bucket_id, name, auth.uid())
  );

CREATE POLICY "secure-files: group member upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'secure-files'
    AND (auth.uid())::text = owner_id::text
  );

CREATE POLICY "Allow owners to update secure-files"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING ( bucket_id = 'secure-files' AND owner_id::text = auth.uid()::text );

CREATE POLICY "secure-files: owner or admin delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'secure-files'
    AND public.can_delete_storage_object(bucket_id, name, auth.uid(), owner_id)
  );

-- =============================================================================
-- SECTION 5: REALTIME PUBLICATION
-- =============================================================================

DO $pub$
DECLARE tbl text;
BEGIN
  FOREACH tbl IN ARRAY ARRAY['study_groups','study_group_members','secure_files','audit_logs','focus_logs','user_notes']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication p
      JOIN pg_publication_rel pr ON pr.prpubid = p.oid
      JOIN pg_class c ON c.oid = pr.prrelid
      WHERE p.pubname = 'supabase_realtime' AND c.relname = tbl
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
    END IF;
  END LOOP;
END $pub$;
