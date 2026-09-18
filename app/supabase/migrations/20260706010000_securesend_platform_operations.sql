-- Migration: 20260706010000_securesend_platform_operations.sql
-- Enables role-based access control, dynamic feature flags, remote configs,
-- and administrative logging for the SecureSend platform.

-- ===========================================================================
-- 1. ROLES & PERMISSIONS
-- ===========================================================================

CREATE TYPE public.user_role AS ENUM ('super_admin', 'admin', 'operator', 'user');

CREATE TABLE IF NOT EXISTS public.user_roles (
    user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role        public.user_role NOT NULL DEFAULT 'user',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_user_roles_role ON public.user_roles(role);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Security Definer to avoid circular policy checks (RLS recursion)
CREATE OR REPLACE FUNCTION public.is_admin(check_user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE user_id = check_user_id AND role IN ('super_admin', 'admin')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_super_admin(check_user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_roles 
        WHERE user_id = check_user_id AND role = 'super_admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Roles Policies
DROP POLICY IF EXISTS "user_roles_select_all" ON public.user_roles;
CREATE POLICY "user_roles_select_all" 
    ON public.user_roles FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "user_roles_write_super" ON public.user_roles;
CREATE POLICY "user_roles_write_super" 
    ON public.user_roles FOR ALL TO authenticated
    USING (public.is_super_admin(auth.uid()))
    WITH CHECK (public.is_super_admin(auth.uid()));

-- Trigger to auto-assign 'user' role on profile creation if not already present
CREATE OR REPLACE FUNCTION public.handle_user_role_setup()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (new.id, 'user')
    ON CONFLICT (user_id) DO NOTHING;
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_created_role ON public.profiles;
CREATE TRIGGER on_profile_created_role
    AFTER INSERT ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_user_role_setup();

-- Backfill existing users (profiles) with 'user' role
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'user'::public.user_role FROM public.profiles
ON CONFLICT (user_id) DO NOTHING;

-- Auto-elevate the first profile to super_admin for bootstrap purposes
UPDATE public.user_roles
SET role = 'super_admin'::public.user_role
WHERE user_id = (SELECT id FROM public.profiles ORDER BY created_at ASC LIMIT 1);

-- ===========================================================================
-- 2. FEATURE FLAGS
-- ===========================================================================

CREATE TABLE IF NOT EXISTS public.feature_flags (
    flag_key              TEXT PRIMARY KEY,
    description           TEXT NOT NULL,
    is_active             BOOLEAN NOT NULL DEFAULT false,
    rollout_percentage    INTEGER NOT NULL DEFAULT 100 CONSTRAINT pct_limit CHECK (rollout_percentage BETWEEN 0 AND 100),
    targeted_user_ids     UUID[] NOT NULL DEFAULT '{}'::uuid[],
    metadata              JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "feature_flags_select_authenticated" ON public.feature_flags;
CREATE POLICY "feature_flags_select_authenticated" 
    ON public.feature_flags FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "feature_flags_write_admin" ON public.feature_flags;
CREATE POLICY "feature_flags_write_admin" 
    ON public.feature_flags FOR ALL TO authenticated
    USING (public.is_admin(auth.uid()))
    WITH CHECK (public.is_admin(auth.uid()));

-- Insert Default SecureSend Flags
INSERT INTO public.feature_flags (flag_key, description, is_active, rollout_percentage) VALUES
('securesend_enabled', 'Master kill-switch for SecureSend link generation and viewing.', true, 100),
('securesend_watermark_enforced', 'Forces recipient email rendering as a visual watermark on documents.', true, 100),
('securesend_blur_enforced', 'Enforces touch-to-reveal blur protection on anonymous share views.', true, 100),
('securesend_custom_expiry', 'Allows creators to customize the expiration times of share links.', true, 100)
ON CONFLICT (flag_key) DO UPDATE 
SET description = excluded.description, is_active = excluded.is_active, rollout_percentage = excluded.rollout_percentage;

-- ===========================================================================
-- 3. REMOTE CONFIGURATIONS
-- ===========================================================================

CREATE TABLE IF NOT EXISTS public.remote_configs (
    config_key   TEXT PRIMARY KEY,
    config_value JSONB NOT NULL,
    description  TEXT NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.remote_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "remote_configs_select_authenticated" ON public.remote_configs;
CREATE POLICY "remote_configs_select_authenticated" 
    ON public.remote_configs FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS "remote_configs_write_admin" ON public.remote_configs;
CREATE POLICY "remote_configs_write_admin" 
    ON public.remote_configs FOR ALL TO authenticated
    USING (public.is_admin(auth.uid()))
    WITH CHECK (public.is_admin(auth.uid()));

-- Insert Default SecureSend Configs
INSERT INTO public.remote_configs (config_key, config_value, description) VALUES
('securesend_max_expiry_days', '30'::jsonb, 'The maximum number of days a share link can remain active before expiring.'),
('securesend_max_views_default', '10'::jsonb, 'The default max views limit when creating a new share link.'),
('min_supported_client_version', '"1.0.0"'::jsonb, 'The minimum supported client version required to prevent locking access.')
ON CONFLICT (config_key) DO UPDATE 
SET config_value = excluded.config_value, description = excluded.description;

-- ===========================================================================
-- 4. ADMINISTRATIVE AUDIT TRAIL
-- ===========================================================================

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id       UUID NOT NULL REFERENCES auth.users(id),
    action         TEXT NOT NULL,
    target_table   TEXT NOT NULL,
    target_key     TEXT NOT NULL,
    previous_value JSONB,
    new_value      JSONB,
    reason         TEXT NOT NULL,
    ip_address     TEXT,
    user_agent     TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin ON public.admin_audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_action ON public.admin_audit_logs(action);

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Admins and Super Admins can read the audit trail
DROP POLICY IF EXISTS "admin_audit_logs_select_admin" ON public.admin_audit_logs;
CREATE POLICY "admin_audit_logs_select_admin" 
    ON public.admin_audit_logs FOR SELECT TO authenticated
    USING (public.is_admin(auth.uid()));

-- System/service role can write logs, or admins can write logs (bypassed on internal RPC triggers)
DROP POLICY IF EXISTS "admin_audit_logs_insert_admin" ON public.admin_audit_logs;
CREATE POLICY "admin_audit_logs_insert_admin" 
    ON public.admin_audit_logs FOR INSERT TO authenticated
    WITH CHECK (public.is_admin(auth.uid()));

-- GRANTS FOR CLIENT APPLICATIONS
GRANT SELECT ON public.feature_flags TO authenticated;
GRANT SELECT ON public.remote_configs TO authenticated;
GRANT SELECT ON public.user_roles TO authenticated;
GRANT SELECT, INSERT ON public.admin_audit_logs TO authenticated;
