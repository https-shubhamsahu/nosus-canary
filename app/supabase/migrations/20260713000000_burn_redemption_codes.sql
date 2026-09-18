-- Migration: 20260713000000_burn_redemption_codes.sql
-- Short redemption codes — an alternate retrieval path for Burn Notes and
-- Burn Files, alongside the existing link (whose URL fragment carries the
-- AES key/IV and never touches the server). A recipient can instead type an
-- 8-character code; the app looks up the key/IV from the server and
-- proceeds through the exact same viewer/claim flow as a link would.
--
-- This is a DELIBERATE, informed change to what "zero-knowledge" means for
-- this one path: the server temporarily holds the key material so a short,
-- human-typeable code can resolve it. Compensating controls: short expiry
-- (capped to the underlying content's own expiry), single-use, and a
-- rate limiter on redemption attempts mirroring burn_files' upload limiter.
-- The link-based path is completely untouched and keeps its original
-- guarantee — this table only ever holds an ADDITIONAL pointer to key
-- material that also exists (encrypted content + key) via the normal path.
--
-- A code and its underlying burn_files/burn_notes row share one burn: since
-- claim_burn_file/read_and_burn_note are already atomic single-use, whichever
-- of {link, code} is used first consumes the content — the other simply
-- stops working. No new burn-semantics logic needed here.

-- ===========================================================================
-- 1. CORE TABLE
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.burn_redemption_codes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code_hash   TEXT NOT NULL UNIQUE, -- HMAC-SHA256(code, REDEMPTION_CODE_SALT), hex — never the plaintext code
    target_kind TEXT NOT NULL CHECK (target_kind IN ('note', 'file')),
    target_id   UUID NOT NULL,
    key_hex     TEXT NOT NULL,
    iv_hex      TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_burn_redemption_codes_cleanup
  ON public.burn_redemption_codes(expires_at, consumed_at);

ALTER TABLE public.burn_redemption_codes ENABLE ROW LEVEL SECURITY;
-- Deliberately ZERO policies — same posture as burn_files. Every access path
-- (create, redeem, cleanup) is edge-function/service-role/cron only, never
-- reachable directly via PostgREST.

-- ===========================================================================
-- 2. ATOMIC SINGLE-USE CLAIM
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.claim_redemption_code(p_code_hash text)
RETURNS public.burn_redemption_codes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.burn_redemption_codes;
BEGIN
  UPDATE public.burn_redemption_codes
     SET consumed_at = now()
   WHERE code_hash = p_code_hash
     AND consumed_at IS NULL
     AND expires_at > now()
  RETURNING * INTO v_row;

  RETURN v_row; -- all-NULL row if no match — caller checks v_row.id IS NULL
END;
$$;

-- Locked to service_role only — invoked exclusively from inside the
-- redeem-code edge function, which also needs to rate-limit by IP hash in
-- the same breath. No reason to expose this over PostgREST.
REVOKE EXECUTE ON FUNCTION public.claim_redemption_code(text) FROM PUBLIC, anon, authenticated;

-- ===========================================================================
-- 3. REDEMPTION-ATTEMPT RATE LIMITING
-- ===========================================================================
-- Mirrors burn_file_upload_counters / check_and_increment_burn_upload_rate
-- exactly (20260710050000_burn_files.sql) — only a salted HMAC hash of the
-- request IP is ever stored, never the raw IP. This limits brute-force
-- guessing against the code space; the code's own entropy (8 chars from a
-- 32-symbol alphabet, ~1.1 trillion combinations) already makes offline
-- brute force impractical within a 20-minute window, so this is
-- defense-in-depth against a scripted/distributed attempt, not the sole
-- protection.
CREATE TABLE IF NOT EXISTS public.burn_redeem_attempt_counters (
    ip_hash       TEXT PRIMARY KEY,
    window_start  TIMESTAMPTZ NOT NULL DEFAULT now(),
    attempt_count INTEGER NOT NULL DEFAULT 0
);

ALTER TABLE public.burn_redeem_attempt_counters ENABLE ROW LEVEL SECURITY;
-- Zero policies — only ever touched via the SECURITY DEFINER function below.

CREATE OR REPLACE FUNCTION public.check_and_increment_redeem_rate(
  p_ip_hash text,
  p_limit int,
  p_window_minutes int
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.burn_redeem_attempt_counters;
BEGIN
  SELECT * INTO v_row FROM public.burn_redeem_attempt_counters WHERE ip_hash = p_ip_hash FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.burn_redeem_attempt_counters (ip_hash, attempt_count) VALUES (p_ip_hash, 1);
    RETURN true;
  END IF;

  IF v_row.window_start < now() - make_interval(mins => p_window_minutes) THEN
    UPDATE public.burn_redeem_attempt_counters
       SET window_start = now(), attempt_count = 1
     WHERE ip_hash = p_ip_hash;
    RETURN true;
  END IF;

  IF v_row.attempt_count >= p_limit THEN
    RETURN false;
  END IF;

  UPDATE public.burn_redeem_attempt_counters SET attempt_count = attempt_count + 1 WHERE ip_hash = p_ip_hash;
  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_and_increment_redeem_rate(text, int, int)
  FROM PUBLIC, anon, authenticated;

-- ===========================================================================
-- 4. FEATURE FLAG + CONFIG (existing feature_flags/remote_configs convention)
-- ===========================================================================
INSERT INTO public.feature_flags (flag_key, description, is_active, rollout_percentage) VALUES
('burn_redemption_codes_enabled', 'Master kill-switch for short-code redemption of Burn Notes/Files.', true, 100)
ON CONFLICT (flag_key) DO UPDATE
SET description = excluded.description, is_active = excluded.is_active;

INSERT INTO public.remote_configs (config_key, config_value, description) VALUES
('redeem_code_ttl_minutes', '20'::jsonb, 'How long a redemption code stays valid, capped to the underlying content''s own expiry.'),
('redeem_rate_limit_per_hour', '10'::jsonb, 'Max redemption attempts per hashed-IP per rolling window.'),
('redeem_rate_limit_window_minutes', '60'::jsonb, 'Rolling window length for the redemption rate limiter.')
ON CONFLICT (config_key) DO UPDATE
SET config_value = excluded.config_value, description = excluded.description;

-- ===========================================================================
-- 5. SCHEDULED CLEANUP
-- ===========================================================================
-- Unlike burn_files, redemption codes have no associated Storage object to
-- delete — this table is pure metadata (key/IV text), so a plain SQL DELETE
-- via pg_cron is sufficient, no pg_net/edge-function round trip needed.
-- Same cadence class as burn_notes' hourly sweep, tightened since the whole
-- point of this table is to hold sensitive key material only briefly.
SELECT cron.schedule(
  'burn-redemption-codes-cleanup',
  '*/10 * * * *',
  $$DELETE FROM public.burn_redemption_codes WHERE expires_at < now() OR consumed_at IS NOT NULL$$
);

-- Sweeps the rate-limit counter table hourly, same pattern as burn_files'.
SELECT cron.schedule(
  'burn-redeem-rate-limit-sweep',
  '0 * * * *',
  $$DELETE FROM public.burn_redeem_attempt_counters WHERE window_start < now() - interval '24 hours'$$
);
