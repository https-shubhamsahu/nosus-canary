-- Migration: storage_router
-- Description: Add a metadata index for optional multi-cloud object storage.
--
-- This is purely additive. Existing Supabase Storage buckets, upload flows,
-- download flows, sharing rules, and secure_files policies remain intact.
-- Provider credentials are never stored here; they live only as Edge Function
-- secrets consumed by supabase/functions/storage-router.

CREATE TABLE IF NOT EXISTS public.storage_objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  group_id text NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
  file_id text NOT NULL REFERENCES public.secure_files(id) ON DELETE CASCADE,
  logical_path text NOT NULL,
  provider text NOT NULL,
  bucket text NOT NULL,
  object_key text NOT NULL,
  size_bytes bigint NOT NULL DEFAULT 0 CHECK (size_bytes >= 0),
  content_type text NOT NULL DEFAULT 'application/octet-stream',
  checksum_sha256 text,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'deleted', 'orphaned')),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  UNIQUE (file_id),
  UNIQUE (user_id, logical_path)
);

CREATE INDEX IF NOT EXISTS idx_storage_objects_user
  ON public.storage_objects(user_id);
CREATE INDEX IF NOT EXISTS idx_storage_objects_group
  ON public.storage_objects(group_id);
CREATE INDEX IF NOT EXISTS idx_storage_objects_provider
  ON public.storage_objects(provider, status);

ALTER TABLE public.storage_objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "storage_objects: group member select" ON public.storage_objects;
CREATE POLICY "storage_objects: group member select"
  ON public.storage_objects FOR SELECT
  TO authenticated
  USING (public.is_group_member(group_id));

DROP POLICY IF EXISTS "storage_objects: owner insert" ON public.storage_objects;
CREATE POLICY "storage_objects: owner insert"
  ON public.storage_objects FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() AND public.is_group_member(group_id));

DROP POLICY IF EXISTS "storage_objects: owner or admin update" ON public.storage_objects;
CREATE POLICY "storage_objects: owner or admin update"
  ON public.storage_objects FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR public.is_group_admin(group_id))
  WITH CHECK (user_id = auth.uid() OR public.is_group_admin(group_id));

DROP POLICY IF EXISTS "storage_objects: owner or admin delete" ON public.storage_objects;
CREATE POLICY "storage_objects: owner or admin delete"
  ON public.storage_objects FOR DELETE
  TO authenticated
  USING (user_id = auth.uid() OR public.is_group_admin(group_id));

CREATE OR REPLACE FUNCTION public.storage_objects_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_storage_objects_touch ON public.storage_objects;
CREATE TRIGGER trg_storage_objects_touch
  BEFORE UPDATE ON public.storage_objects
  FOR EACH ROW EXECUTE FUNCTION public.storage_objects_touch_updated_at();

-- Supabase projects created after April 28, 2026 may not expose new public
-- tables automatically. Keep permissions explicit while RLS enforces rows.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.storage_objects TO authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.storage_objects;
    EXCEPTION WHEN duplicate_object THEN
      NULL;
    END;
  END IF;
END $$;
