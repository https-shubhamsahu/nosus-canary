-- Migration: 20260704000000_fhe_subsystem.sql
-- Description: Isolated FHE subsystem metadata tables.
--
-- SAFETY / ARCHITECTURE NOTES
--   * This migration is PURELY ADDITIVE. It touches no existing table, policy,
--     RPC, or storage bucket. Existing AES storage, sharing, viewing, auth and
--     RLS are untouched.
--   * NO secret key material is ever stored here. Supabase holds METADATA ONLY.
--     ClientKeys never leave the device; Server/Evaluation keys live only in
--     the Rust microservice's protected memory.
--   * Every table is tenant-isolated by user_id = auth.uid() via RLS.
--   * fhe_events is append-only (no UPDATE/DELETE policy for end users).

-- ===========================================================================
-- 1. KEY METADATA  (fingerprints + lifecycle only, never the keys themselves)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.fhe_key_metadata (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    key_id          TEXT NOT NULL,
    device_id       TEXT,
    algorithm       TEXT NOT NULL DEFAULT 'TFHE-rs',
    param_version   TEXT NOT NULL DEFAULT 'v1',
    tfhe_version    TEXT NOT NULL DEFAULT '0.6',
    protocol_version TEXT NOT NULL DEFAULT 'v1',
    -- SHA-256 fingerprint of the public/evaluation key for integrity checks.
    -- A hash is NOT secret and cannot reconstruct the key.
    public_fingerprint TEXT,
    status          TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','rotated','revoked','expired')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    expires_at      TIMESTAMPTZ,
    rotated_at      TIMESTAMPTZ,
    revoked_at      TIMESTAMPTZ,
    UNIQUE (user_id, key_id)
);

CREATE INDEX IF NOT EXISTS idx_fhe_key_metadata_user   ON public.fhe_key_metadata (user_id);
CREATE INDEX IF NOT EXISTS idx_fhe_key_metadata_status ON public.fhe_key_metadata (status);

ALTER TABLE public.fhe_key_metadata ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fhe_key_metadata_select_own" ON public.fhe_key_metadata;
CREATE POLICY "fhe_key_metadata_select_own"
    ON public.fhe_key_metadata FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "fhe_key_metadata_insert_own" ON public.fhe_key_metadata;
CREATE POLICY "fhe_key_metadata_insert_own"
    ON public.fhe_key_metadata FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "fhe_key_metadata_update_own" ON public.fhe_key_metadata;
CREATE POLICY "fhe_key_metadata_update_own"
    ON public.fhe_key_metadata FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ===========================================================================
-- 2. COMPUTE JOBS  (async job queue mirror for realtime status)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.fhe_compute_jobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    key_id          TEXT NOT NULL,
    operation       TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','queued','running','completed','failed','cancelled','dead_letter')),
    priority        SMALLINT NOT NULL DEFAULT 1,
    progress        REAL NOT NULL DEFAULT 0.0,
    -- Homomorphic RESULT ciphertext only (still encrypted; decryptable solely
    -- by the client's ClientKey). Nullable until the job completes.
    result_ciphertext TEXT,
    error           TEXT,
    attempts        SMALLINT NOT NULL DEFAULT 0,
    timeout_seconds INTEGER NOT NULL DEFAULT 30,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    completed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_fhe_jobs_user   ON public.fhe_compute_jobs (user_id);
CREATE INDEX IF NOT EXISTS idx_fhe_jobs_status ON public.fhe_compute_jobs (status);

ALTER TABLE public.fhe_compute_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fhe_jobs_select_own" ON public.fhe_compute_jobs;
CREATE POLICY "fhe_jobs_select_own"
    ON public.fhe_compute_jobs FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "fhe_jobs_insert_own" ON public.fhe_compute_jobs;
CREATE POLICY "fhe_jobs_insert_own"
    ON public.fhe_compute_jobs FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Users may only cancel their own jobs (status -> cancelled). The worker
-- (service_role, which bypasses RLS) performs all other status transitions.
DROP POLICY IF EXISTS "fhe_jobs_cancel_own" ON public.fhe_compute_jobs;
CREATE POLICY "fhe_jobs_cancel_own"
    ON public.fhe_compute_jobs FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ===========================================================================
-- 3. EVENT LEDGER  (append-only; integrates with the NO SUS audit philosophy)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.fhe_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    job_id      UUID,
    event_type  TEXT NOT NULL
                CHECK (event_type IN (
                    'fhe_key_generated','fhe_key_rotated','fhe_key_revoked',
                    'fhe_compute_started','fhe_compute_completed','fhe_compute_failed',
                    'fhe_budget_exceeded','fhe_job_cancelled','fhe_replay_detected',
                    'fhe_discovery_started','fhe_discovery_completed'
                )),
    -- Aggregate / non-sensitive metadata ONLY. Never plaintext, ciphertext,
    -- key material, or key fingerprints.
    metadata    JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_fhe_events_user ON public.fhe_events (user_id);
CREATE INDEX IF NOT EXISTS idx_fhe_events_type ON public.fhe_events (event_type);
CREATE INDEX IF NOT EXISTS idx_fhe_events_time ON public.fhe_events (created_at);

ALTER TABLE public.fhe_events ENABLE ROW LEVEL SECURITY;

-- Users can read their own audit trail. Inserts happen from the Edge Function
-- (service_role) so the ledger cannot be forged by clients. No UPDATE/DELETE
-- policy exists => the ledger is append-only for everyone but service_role.
DROP POLICY IF EXISTS "fhe_events_select_own" ON public.fhe_events;
CREATE POLICY "fhe_events_select_own"
    ON public.fhe_events FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Supabase projects created after April 28, 2026 may not expose new public
-- tables to the Data API automatically. Explicit grants keep the Flutter client
-- able to read its RLS-scoped metadata while RLS remains the row-level guard.
GRANT SELECT, INSERT, UPDATE ON public.fhe_key_metadata TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.fhe_compute_jobs TO authenticated;
GRANT SELECT ON public.fhe_events TO authenticated;

-- ===========================================================================
-- 4. AUTO-UPDATE updated_at ON JOBS
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.fhe_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := timezone('utc', now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_fhe_jobs_touch ON public.fhe_compute_jobs;
CREATE TRIGGER trg_fhe_jobs_touch
    BEFORE UPDATE ON public.fhe_compute_jobs
    FOR EACH ROW EXECUTE FUNCTION public.fhe_touch_updated_at();

-- ===========================================================================
-- 5. REALTIME  (client subscribes to its own job rows for push notifications)
-- ===========================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        BEGIN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.fhe_compute_jobs;
        EXCEPTION WHEN duplicate_object THEN
            NULL; -- already added
        END;
    END IF;
END $$;
