-- Follow-up to 20260710030000_risk_engine.sql: the advisor caught two real
-- gaps missed in the original migration.
--
-- 1. risk_signal_weights / risk_tiers were created WITHOUT
--    `ENABLE ROW LEVEL SECURITY` at all — not just missing a policy, RLS was
--    never turned on, so PostgREST's default grants would have controlled
--    access instead of anything this migration intended.
ALTER TABLE public.risk_signal_weights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_tiers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "risk_signal_weights: authenticated read"
  ON public.risk_signal_weights FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "risk_tiers: authenticated read"
  ON public.risk_tiers FOR SELECT
  TO authenticated
  USING (true);

-- No INSERT/UPDATE/DELETE policies — these are admin-tunable config tables,
-- changed via direct SQL (or a future admin console), never by the app.

-- 2. recompute_user_risk() and the two trigger functions are meant to run
--    ONLY as part of the AFTER INSERT trigger chain, never as a directly
--    callable RPC — PostgREST exposes every SECURITY DEFINER function by
--    default, so without this REVOKE any authenticated user could call
--    recompute_user_risk('someone-elses-uuid', ...) directly, forcing
--    side effects (alert rows, device-ledger inserts) on another account.
-- Trigger invocation does not require EXECUTE privilege (it isn't a normal
-- SQL call), so this does not affect the triggers created in the prior
-- migration — only direct RPC/PostgREST access is blocked.
REVOKE EXECUTE ON FUNCTION public.recompute_user_risk(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_recompute_risk_from_audit_logs() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_recompute_risk_from_device_integrity() FROM PUBLIC, anon, authenticated;
