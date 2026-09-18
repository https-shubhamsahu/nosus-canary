-- Migration: 20260707000000_drop_orphaned_revoke_device.sql
-- public.revoke_device() references public.devices, which was already dropped
-- as an orphaned table in 20260706000000_drop_experiment_subsystems.sql (that
-- migration dropped the table but missed this function). No client code calls
-- it (grep confirms zero references in lib/ or supabase/functions/), so it's
-- dead and currently broken (any call errors: relation "devices" does not
-- exist) while still being flagged by the security advisor as an
-- unrestricted anon-callable SECURITY DEFINER function. Safe to drop.

DROP FUNCTION IF EXISTS public.revoke_device(uuid);
