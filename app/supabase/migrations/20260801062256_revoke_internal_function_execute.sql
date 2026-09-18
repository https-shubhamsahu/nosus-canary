-- Follow-up to 20260730112424_group_moderation and 20260730112523_notifications.
--
-- Applied 2026-08-01. The filename carries the ledger version it actually
-- landed under (20260801062256), not the 20260730120000 it was drafted as —
-- they must match or `supabase db push` re-runs this as if it were new.
--
-- PostgREST exposes every function in `public` as /rest/v1/rpc/<name>, and the
-- two trigger functions landed with the default PUBLIC execute grant. Calling a
-- trigger function directly always fails ("trigger functions can only be called
-- as triggers"), so nothing here was exploitable — but they have no business
-- being in the API surface, and the database linter flags them
-- (0028/0029 *_security_definer_function_executable).
REVOKE EXECUTE ON FUNCTION public.trg_notify_membership() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_notify_new_document() FROM public, anon, authenticated;

-- These two are only ever called from inside SECURITY DEFINER bodies, which run
-- as the owner and do not need the caller to hold EXECUTE. Granting them to
-- `authenticated` let any signed-in account resolve an arbitrary user id to a
-- display name, or probe whether a given user is banned from a given group.
-- Verified: no client code and no edge function calls either one.
REVOKE EXECUTE ON FUNCTION public.group_member_label(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.is_group_banned(text, uuid) FROM authenticated;

-- shares_group_with() keeps its grant on purpose: it is evaluated inside the
-- profiles SELECT policy, and RLS policy expressions run as the querying role,
-- not as the policy owner. Revoking it would break every profile read.
