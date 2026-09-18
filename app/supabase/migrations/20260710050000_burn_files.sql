-- Migration: 20260710050000_burn_files.sql
-- "Burn Files" — anonymous, no-login file drop. Upload a file, get a link,
-- the file is permanently deleted from storage after first download or a
-- time limit, whichever comes first (file.io's "dual deletion trigger").
--
-- Modeled on two existing features, neither of which alone solves this:
--   - burn_notes: zero-knowledge client-side encryption (key/IV never touch
--     the server) + atomic burn-on-read. Text-only, ciphertext inline in a
--     column, so a plain DELETE erases it.
--   - SecureSend (share_links / share-fetch): moves real file bytes through
--     Storage with signed URLs, but NOTHING in this codebase deletes the
--     actual storage object on expiry/exhaustion, and view-count enforcement
--     is non-atomic. This migration does not touch SecureSend at all — it's
--     a parallel, independent system.
--
-- Since upload here is genuinely anonymous (no auth on either end, per
-- product decision), this migration also includes rate-limiting that
-- burn_notes never needed — an unthrottled anonymous upload endpoint is a
-- real exploitable resource, not just a feature gap.

-- ===========================================================================
-- 1. STORAGE BUCKET
-- ===========================================================================
-- Private, separate from secure-files for clean lifecycle/RLS isolation.
-- 50MB — double the existing secure-files cap (25MB), still comfortably
-- under the ~100-150MB memory-safety heuristic from client-side AES-CBC
-- having no streaming API (peak memory is ~2-3x file size on both native
-- and web). Not file.io's 4GB — that's a deliberate, conservative choice.
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('burn-files', 'burn-files', false, 52428800)
ON CONFLICT (id) DO NOTHING;

-- Deliberately NO storage.objects RLS policies for anon/authenticated —
-- every access path (upload via signed upload URL, download via signed
-- download URL, delete via the cleanup sweep) goes through a service-role
-- edge function. Nothing here is ever reachable directly by a client role.

-- ===========================================================================
-- 2. CORE TABLE
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.burn_files (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    storage_object_key    TEXT NOT NULL,
    status                TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'ready')),
    ciphertext_size_bytes BIGINT NOT NULL CHECK (ciphertext_size_bytes > 0 AND ciphertext_size_bytes <= 104857600),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at            TIMESTAMPTZ NOT NULL,
    consumed_at           TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_burn_files_cleanup
  ON public.burn_files(status, expires_at, consumed_at);

ALTER TABLE public.burn_files ENABLE ROW LEVEL SECURITY;
-- Deliberately ZERO policies — stronger than burn_notes (which still has an
-- open anon INSERT policy). Row creation here must pass through the rate
-- limiter first, which needs server-side IP hashing an RLS WITH CHECK
-- clause can't perform. Every access path is edge-function/service-role.

-- ===========================================================================
-- 3. ATOMIC SINGLE-USE CLAIM
-- ===========================================================================
-- burn_notes needed a follow-up hardening migration to make its
-- read-and-burn RPC atomic (a prior check-then-delete had a race under
-- concurrent reads). This bakes the fix in from day one: a single
-- UPDATE ... RETURNING can only ever succeed once per row.
CREATE OR REPLACE FUNCTION public.claim_burn_file(p_id uuid)
RETURNS public.burn_files
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.burn_files;
BEGIN
  UPDATE public.burn_files
     SET consumed_at = now()
   WHERE id = p_id
     AND status = 'ready'
     AND consumed_at IS NULL
     AND expires_at > now()
  RETURNING * INTO v_row;

  RETURN v_row; -- all-NULL row if no match (0 rows updated) — caller checks v_row.id IS NULL
END;
$$;

-- Locked to service_role only — unlike read_and_burn_note (which anon calls
-- directly via PostgREST), this RPC is only ever invoked from inside the
-- burn-file-fetch edge function, which also needs a service-role Storage
-- signed-URL call in the same breath. No reason to expose it over PostgREST.
REVOKE EXECUTE ON FUNCTION public.claim_burn_file(uuid) FROM PUBLIC, anon, authenticated;

-- ===========================================================================
-- 4. ANONYMOUS-UPLOAD RATE LIMITING
-- ===========================================================================
-- Only a salted HMAC hash of the request IP is ever stored (computed in the
-- burn-file-init edge function) — never the raw IP — consistent with the
-- privacy policy's no-tracking commitment. Swept hourly so no hash outlives
-- its usefulness.
CREATE TABLE IF NOT EXISTS public.burn_file_upload_counters (
    ip_hash      TEXT PRIMARY KEY,
    window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
    upload_count INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE public.burn_file_upload_counters ENABLE ROW LEVEL SECURITY;
-- Zero policies — only ever touched via the SECURITY DEFINER function below.

CREATE OR REPLACE FUNCTION public.check_and_increment_burn_upload_rate(
  p_ip_hash text,
  p_limit int,
  p_window_minutes int
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.burn_file_upload_counters;
BEGIN
  SELECT * INTO v_row FROM public.burn_file_upload_counters WHERE ip_hash = p_ip_hash FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.burn_file_upload_counters (ip_hash, upload_count) VALUES (p_ip_hash, 1);
    RETURN true;
  END IF;

  IF v_row.window_start < now() - make_interval(mins => p_window_minutes) THEN
    UPDATE public.burn_file_upload_counters
       SET window_start = now(), upload_count = 1
     WHERE ip_hash = p_ip_hash;
    RETURN true;
  END IF;

  IF v_row.upload_count >= p_limit THEN
    RETURN false;
  END IF;

  UPDATE public.burn_file_upload_counters SET upload_count = upload_count + 1 WHERE ip_hash = p_ip_hash;
  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_and_increment_burn_upload_rate(text, int, int)
  FROM PUBLIC, anon, authenticated;

-- ===========================================================================
-- 5. FEATURE FLAG + CONFIG (existing feature_flags/remote_configs convention)
-- ===========================================================================
INSERT INTO public.feature_flags (flag_key, description, is_active, rollout_percentage) VALUES
('burn_files_enabled', 'Master kill-switch for Burn Files upload/download.', true, 100)
ON CONFLICT (flag_key) DO UPDATE
SET description = excluded.description, is_active = excluded.is_active;

INSERT INTO public.remote_configs (config_key, config_value, description) VALUES
('burn_files_max_size_bytes', '52428800'::jsonb, 'Max encrypted blob size for a Burn File upload (50MB default).'),
('burn_files_default_expiry_hours', '24'::jsonb, 'Default TTL for a new Burn File when the sender does not choose one.'),
('burn_files_max_expiry_hours', '168'::jsonb, 'Max TTL a sender may request (7 days).'),
('burn_files_rate_limit_per_hour', '8'::jsonb, 'Max uploads per hashed-IP per rolling window.'),
('burn_files_rate_limit_window_minutes', '60'::jsonb, 'Rolling window length for the upload rate limiter.')
ON CONFLICT (config_key) DO UPDATE
SET config_value = excluded.config_value, description = excluded.description;

-- ===========================================================================
-- 6. SCHEDULED CLEANUP (first use of pg_net in this project)
-- ===========================================================================
-- pg_cron cannot call the Storage REST API directly — deleting an object
-- requires an actual HTTP call. pg_net is the async-HTTP bridge Supabase
-- provides for exactly this: cron -> pg_net -> edge function -> Storage API.
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Sweeps the rate-limit counter table hourly, same cadence/pattern as the
-- existing burn_notes expiry sweep.
SELECT cron.schedule(
  'burn-file-rate-limit-sweep',
  '0 * * * *',
  $$DELETE FROM public.burn_file_upload_counters WHERE window_start < now() - interval '24 hours'$$
);

-- The main cleanup sweep — every 5 minutes, tighter than burn_notes' hourly
-- sweep, since "permanently deleted" for real file bytes is a stated product
-- promise, not just row housekeeping. Authenticated via a shared secret in
-- Supabase Vault (created once, out-of-band — see deployment notes; never
-- committed as a literal value in this file). The cron job only looks the
-- secret up by name at execution time.
SELECT cron.schedule(
  'burn-files-cleanup-sweep',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://rxfnazmusofikwaggntb.supabase.co/functions/v1/cleanup-burn-files',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'burn_files_cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);
