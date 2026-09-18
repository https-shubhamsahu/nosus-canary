-- Migration: 20260707050000_avatars_bucket.sql
-- Public bucket for user profile pictures. Avatars are low-sensitivity,
-- displayed in headers/rosters, so public-read keeps rendering trivial
-- (plain URL, browser-cacheable — no signed-URL churn). Writes are locked
-- to the owner: each user manages exactly one object named <uid>.png.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 1048576, ARRAY['image/png'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "avatars_insert_own" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'avatars' AND name = auth.uid()::text || '.png');

CREATE POLICY "avatars_update_own" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND name = auth.uid()::text || '.png');

CREATE POLICY "avatars_delete_own" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'avatars' AND name = auth.uid()::text || '.png');

CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');
