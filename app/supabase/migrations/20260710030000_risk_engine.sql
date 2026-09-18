-- Phase 3 hardening: deterministic, rule-based risk scoring.
--
-- Deliberately NOT machine learning — a fixed, auditable weight table that
-- an admin can retune in SQL (or a future admin console) without redeploying
-- app code. Every signal here has a real detector feeding it (Phase 1's
-- device_integrity_events, Phase 1/2's audit_logs event types). Two event
-- types already exist in device_integrity_events' CHECK constraint —
-- multiple_device_access and unusual_location_detected — as schema-ready
-- extensibility hooks, but NO detector populates them yet (would need a
-- concurrent-session tracker / IP geolocation lookup this app doesn't have).
-- They're included below so the engine picks them up automatically the day
-- someone builds that detector, but until then they will simply never fire.

-- 1. Configurable signal weights ---------------------------------------------
CREATE TABLE IF NOT EXISTS public.risk_signal_weights (
    signal_type text PRIMARY KEY,
    source text NOT NULL CHECK (source IN ('audit_logs', 'device_integrity_events')),
    weight int NOT NULL CHECK (weight >= 0),
    window_minutes int NOT NULL CHECK (window_minutes > 0),
    enabled boolean NOT NULL DEFAULT true
);

INSERT INTO public.risk_signal_weights (signal_type, source, weight, window_minutes) VALUES
    ('screenshot_attempt',           'audit_logs',               15, 1440),
    ('recording_attempt',            'audit_logs',               25, 1440),
    ('overlay_detected',             'audit_logs',               20, 1440),
    ('accessibility_detected',       'audit_logs',               15, 1440),
    ('display_mirroring_detected',   'audit_logs',               10, 1440),
    ('unauthorized_access',          'audit_logs',               30, 1440),
    ('root_detected',                'device_integrity_events',  10, 43200),
    ('tamper_detected',              'device_integrity_events',  40, 43200),
    ('device_risk_flagged',          'device_integrity_events',  20, 1440),
    ('multiple_device_access',       'device_integrity_events',  15, 1440),
    ('unusual_location_detected',    'device_integrity_events',  20, 1440)
ON CONFLICT (signal_type) DO NOTHING;

-- 2. Configurable tiers -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.risk_tiers (
    tier text PRIMARY KEY,
    min_score int NOT NULL,
    actions text[] NOT NULL DEFAULT '{}'
);

INSERT INTO public.risk_tiers (tier, min_score, actions) VALUES
    ('low',      0,   '{}'),
    ('elevated', 30,  '{increase_watermark}'),
    ('high',     60,  '{increase_watermark,require_reauth,notify_admin}'),
    ('critical', 100, '{increase_watermark,lock_session,require_reauth,notify_admin,notify_owner}')
ON CONFLICT (tier) DO NOTHING;

-- 3. Per-user computed state --------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_risk_state (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    score int NOT NULL DEFAULT 0,
    tier text NOT NULL DEFAULT 'low' REFERENCES public.risk_tiers(tier),
    watermark_intensity text NOT NULL DEFAULT 'normal'
        CHECK (watermark_intensity IN ('normal', 'increased', 'maximum')),
    session_locked boolean NOT NULL DEFAULT false,
    require_reauth boolean NOT NULL DEFAULT false,
    breakdown jsonb NOT NULL DEFAULT '{}'::jsonb,
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_risk_state ENABLE ROW LEVEL SECURITY;

CREATE POLICY "risk_state: self or super admin select"
  ON public.user_risk_state FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.is_super_admin(auth.uid()));

-- No INSERT/UPDATE/DELETE policies at all — every write goes through
-- recompute_user_risk() / acknowledge_reauth() below (SECURITY DEFINER),
-- so a client can never set its own risk score to "low" directly.

-- 4. Alerts for admins / group owners ----------------------------------------
CREATE TABLE IF NOT EXISTS public.security_alerts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    group_id text REFERENCES public.study_groups(id) ON DELETE SET NULL,
    tier text NOT NULL,
    score int NOT NULL,
    breakdown jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    acknowledged boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_security_alerts_group ON public.security_alerts(group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_alerts_user ON public.security_alerts(user_id, created_at DESC);

ALTER TABLE public.security_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "security_alerts: self, group admin, or super admin select"
  ON public.security_alerts FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_super_admin(auth.uid())
    OR (group_id IS NOT NULL AND public.is_group_admin(group_id))
  );

-- No direct UPDATE policy — acknowledgement goes through
-- acknowledge_security_alert() so the admin-or-owner check is enforced
-- server-side rather than trusted to RLS on a mutable column.

-- 5. Core scoring function ----------------------------------------------------
-- p_context_group_id: the group the triggering event happened in, if any
-- (passed through purely so a resulting alert can be seen by that group's
-- admin — the score itself is always computed across ALL of the user's
-- groups and devices, not just this one).
CREATE OR REPLACE FUNCTION public.recompute_user_risk(
  p_user_id uuid,
  p_context_group_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  total_score int := 0;
  chosen_tier text;
  chosen_actions text[];
  prev_tier text;
  breakdown jsonb := '{}'::jsonb;
  rec record;
BEGIN
  FOR rec IN
    SELECT w.signal_type, w.weight, count(*) AS cnt
    FROM public.device_integrity_events e
    JOIN public.risk_signal_weights w
      ON w.signal_type = e.event_type AND w.source = 'device_integrity_events' AND w.enabled
    WHERE e.user_id = p_user_id
      AND e.created_at > now() - (w.window_minutes || ' minutes')::interval
    GROUP BY w.signal_type, w.weight
  LOOP
    total_score := total_score + (rec.weight * rec.cnt);
    breakdown := breakdown || jsonb_build_object(rec.signal_type, rec.cnt);
  END LOOP;

  FOR rec IN
    SELECT w.signal_type, w.weight, count(*) AS cnt
    FROM public.audit_logs a
    JOIN public.risk_signal_weights w
      ON w.signal_type = a.event_type AND w.source = 'audit_logs' AND w.enabled
    WHERE a.actor_id = p_user_id
      AND a.created_at > now() - (w.window_minutes || ' minutes')::interval
    GROUP BY w.signal_type, w.weight
  LOOP
    total_score := total_score + (rec.weight * rec.cnt);
    breakdown := breakdown || jsonb_build_object(rec.signal_type, rec.cnt);
  END LOOP;

  SELECT tier, actions INTO chosen_tier, chosen_actions
  FROM public.risk_tiers
  WHERE min_score <= total_score
  ORDER BY min_score DESC
  LIMIT 1;

  IF chosen_tier IS NULL THEN
    chosen_tier := 'low';
    chosen_actions := '{}';
  END IF;

  SELECT tier INTO prev_tier FROM public.user_risk_state WHERE user_id = p_user_id;

  INSERT INTO public.user_risk_state (
    user_id, score, tier, watermark_intensity, session_locked, require_reauth, breakdown, updated_at
  )
  VALUES (
    p_user_id,
    total_score,
    chosen_tier,
    CASE
      WHEN chosen_tier = 'critical' THEN 'maximum'
      WHEN 'increase_watermark' = ANY(chosen_actions) THEN 'increased'
      ELSE 'normal'
    END,
    'lock_session' = ANY(chosen_actions),
    'require_reauth' = ANY(chosen_actions),
    breakdown,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    score = EXCLUDED.score,
    tier = EXCLUDED.tier,
    watermark_intensity = EXCLUDED.watermark_intensity,
    session_locked = EXCLUDED.session_locked,
    require_reauth = EXCLUDED.require_reauth,
    breakdown = EXCLUDED.breakdown,
    updated_at = now();

  -- Alert on escalation INTO high/critical only — not every recompute, so a
  -- user sitting at 'critical' doesn't generate a fresh alert on every
  -- unrelated security event that happens to also be scored.
  IF chosen_tier IN ('high', 'critical') AND prev_tier IS DISTINCT FROM chosen_tier THEN
    INSERT INTO public.security_alerts (user_id, group_id, tier, score, breakdown)
    VALUES (p_user_id, p_context_group_id, chosen_tier, total_score, breakdown);
  END IF;

  -- Log the enforcement action itself into the device ledger — this is what
  -- makes 'session_locked' a real, populated event type rather than a dead
  -- CHECK-constraint value. Safe against re-triggering the risk recompute
  -- below: 'session_locked' isn't itself a scored signal_type.
  IF chosen_tier = 'critical' AND prev_tier IS DISTINCT FROM chosen_tier THEN
    INSERT INTO public.device_integrity_events (user_id, device_id, event_type, severity, metadata)
    VALUES (p_user_id, 'system', 'session_locked', 'critical', jsonb_build_object('score', total_score));
  END IF;

  RETURN jsonb_build_object('score', total_score, 'tier', chosen_tier, 'actions', to_jsonb(chosen_actions));
END;
$$;

-- 6. Triggers: recompute only when the inserted event is an actual scored
--    signal (skips the vast majority of ordinary audit_logs inserts like
--    file_uploaded/member_joined without a per-row lookup cost on every one).
CREATE OR REPLACE FUNCTION public.trg_recompute_risk_from_audit_logs()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.risk_signal_weights
    WHERE signal_type = NEW.event_type AND source = 'audit_logs' AND enabled
  ) THEN
    PERFORM public.recompute_user_risk(NEW.actor_id, NEW.group_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_risk_from_audit_logs ON public.audit_logs;
CREATE TRIGGER trg_risk_from_audit_logs
  AFTER INSERT ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.trg_recompute_risk_from_audit_logs();

CREATE OR REPLACE FUNCTION public.trg_recompute_risk_from_device_integrity()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.risk_signal_weights
    WHERE signal_type = NEW.event_type AND source = 'device_integrity_events' AND enabled
  ) THEN
    PERFORM public.recompute_user_risk(NEW.user_id, NULL);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_risk_from_device_integrity ON public.device_integrity_events;
CREATE TRIGGER trg_risk_from_device_integrity
  AFTER INSERT ON public.device_integrity_events
  FOR EACH ROW EXECUTE FUNCTION public.trg_recompute_risk_from_device_integrity();

-- 7. RPC: the client calls this right after a fresh, successful sign-in to
--    satisfy a require_reauth / session_locked gate. Safe to expose broadly
--    because it only ever clears the CALLER's own flags — it cannot be used
--    to clear anyone else's lock, and a genuinely fresh authentication is
--    exactly what "require reauth" was asking for.
CREATE OR REPLACE FUNCTION public.acknowledge_reauth()
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.user_risk_state
  SET require_reauth = false, session_locked = false, updated_at = now()
  WHERE user_id = auth.uid();

  RETURN true;
END;
$$;

-- 8. RPC: admin/owner acknowledges an alert (dismisses it from their queue).
CREATE OR REPLACE FUNCTION public.acknowledge_security_alert(p_alert_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  alert_group_id text;
BEGIN
  SELECT group_id INTO alert_group_id FROM public.security_alerts WHERE id = p_alert_id;

  IF alert_group_id IS NULL THEN
    IF NOT public.is_super_admin(auth.uid()) THEN
      RAISE EXCEPTION 'Not authorized to acknowledge this alert';
    END IF;
  ELSIF NOT (public.is_super_admin(auth.uid()) OR public.is_group_admin(alert_group_id)) THEN
    RAISE EXCEPTION 'Not authorized to acknowledge this alert';
  END IF;

  UPDATE public.security_alerts SET acknowledged = true WHERE id = p_alert_id;
  RETURN true;
END;
$$;
