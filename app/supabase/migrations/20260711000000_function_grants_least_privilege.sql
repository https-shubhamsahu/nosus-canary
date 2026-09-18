-- Function-grant least privilege
--
-- Postgres grants EXECUTE on new functions to PUBLIC by default, so every
-- SECURITY DEFINER RPC created before the burn_files/risk_engine era was
-- callable by the `anon` role via /rest/v1/rpc/*. Newer migrations
-- (20260710050000_burn_files.sql, 20260710030000_risk_engine.sql) already
-- revoke default grants on their functions; this migration applies the same
-- pattern to the older ones, flagged by Supabase's security advisor
-- (anon_security_definer_function_executable).
--
-- Grant tiers:
--   trigger-only  → no client role may EXECUTE (triggers run as definer/owner)
--   authenticated → app RPCs that require a session (their bodies already
--                   check auth.uid(); this adds a grant-level wall in front)
--   anon + authenticated → RPCs that are anonymous BY DESIGN:
--       read_and_burn_note  (burn-note claim happens without an account)
--       get_invite_details  (invite landing screen renders pre-login)

-- ── Trigger functions: never client-callable ────────────────────────────────
revoke execute on function public.audit_logs_hash_trigger() from public, anon, authenticated;
revoke execute on function public.device_integrity_events_hash_trigger() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.handle_user_role_setup() from public, anon, authenticated;
revoke execute on function public.update_study_group_file_count() from public, anon, authenticated;

-- ── Authenticated-only RPCs and RLS helper functions ────────────────────────
revoke execute on function public.acknowledge_reauth() from public, anon;
grant execute on function public.acknowledge_reauth() to authenticated;

revoke execute on function public.acknowledge_security_alert(uuid) from public, anon;
grant execute on function public.acknowledge_security_alert(uuid) to authenticated;

revoke execute on function public.can_access_storage_object(text, text, uuid) from public, anon;
grant execute on function public.can_access_storage_object(text, text, uuid) to authenticated;

revoke execute on function public.can_delete_storage_object(text, text, uuid, text) from public, anon;
grant execute on function public.can_delete_storage_object(text, text, uuid, text) to authenticated;

revoke execute on function public.create_study_group_with_creator(text, text, text, boolean, text) from public, anon;
grant execute on function public.create_study_group_with_creator(text, text, text, boolean, text) to authenticated;

revoke execute on function public.ensure_community_exists(text, text) from public, anon;
grant execute on function public.ensure_community_exists(text, text) to authenticated;

revoke execute on function public.is_admin(uuid) from public, anon;
grant execute on function public.is_admin(uuid) to authenticated;

revoke execute on function public.is_group_admin(text) from public, anon;
grant execute on function public.is_group_admin(text) to authenticated;

revoke execute on function public.is_group_member(text) from public, anon;
grant execute on function public.is_group_member(text) to authenticated;

revoke execute on function public.is_super_admin(uuid) from public, anon;
grant execute on function public.is_super_admin(uuid) to authenticated;

revoke execute on function public.join_group_by_invite_code(text) from public, anon;
grant execute on function public.join_group_by_invite_code(text) to authenticated;

revoke execute on function public.join_group_by_invite_link(text) from public, anon;
grant execute on function public.join_group_by_invite_link(text) to authenticated;

revoke execute on function public.join_public_group_by_name(text) from public, anon;
grant execute on function public.join_public_group_by_name(text) to authenticated;

revoke execute on function public.log_device_integrity_event(text, text, text, jsonb) from public, anon;
grant execute on function public.log_device_integrity_event(text, text, text, jsonb) to authenticated;

revoke execute on function public.log_group_event(text, text, text, jsonb) from public, anon;
grant execute on function public.log_group_event(text, text, text, jsonb) to authenticated;

revoke execute on function public.register_device_seen(text) from public, anon;
grant execute on function public.register_device_seen(text) to authenticated;

revoke execute on function public.verify_audit_chain(text) from public, anon;
grant execute on function public.verify_audit_chain(text) to authenticated;

revoke execute on function public.verify_device_integrity_chain(uuid) from public, anon;
grant execute on function public.verify_device_integrity_chain(uuid) to authenticated;

-- ── Anonymous-by-design RPCs: replace implicit PUBLIC with explicit grants ──
revoke execute on function public.read_and_burn_note(uuid) from public;
grant execute on function public.read_and_burn_note(uuid) to anon, authenticated;

revoke execute on function public.get_invite_details(text) from public;
grant execute on function public.get_invite_details(text) to anon, authenticated;

-- ── Storage: avatars bucket listing ─────────────────────────────────────────
-- The app reads avatars exclusively through getPublicUrl() (public-bucket URL
-- endpoint, which does not consult RLS). The broad SELECT policy only enabled
-- authenticated/anon API clients to LIST every object in the bucket — file
-- names are user ids, so that leaked the user list. Flagged by the advisor
-- (public_bucket_allows_listing). Drop it; upload/update/delete stay owner-scoped.
drop policy if exists avatars_public_read on storage.objects;
