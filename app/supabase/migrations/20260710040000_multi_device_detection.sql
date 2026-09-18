-- Closes a gap flagged (not silently dropped) in 20260710030000_risk_engine.sql:
-- 'multiple_device_access' had a risk_signal_weights row but no detector.
-- This is the detector — no external infra needed (no IP geolocation, no
-- session-tracking service), just a per-user table of devices seen before.
--
-- 'unusual_location_detected' remains undetected on purpose: that one
-- genuinely needs an IP geolocation lookup, which means picking a provider
-- (and likely a paid tier) — a product decision, not something to wire up
-- silently.

CREATE TABLE IF NOT EXISTS public.user_known_devices (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id text NOT NULL,
    first_seen_at timestamptz NOT NULL DEFAULT now(),
    last_seen_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, device_id)
);

ALTER TABLE public.user_known_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_known_devices: self select"
  ON public.user_known_devices FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- No direct INSERT/UPDATE policy — writes go through register_device_seen()
-- so the "is this genuinely new" check and the resulting ledger entry can't
-- be spoofed by a client inserting rows directly.

CREATE OR REPLACE FUNCTION public.register_device_seen(p_device_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  is_new boolean;
  known_count int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT NOT EXISTS (
    SELECT 1 FROM public.user_known_devices
    WHERE user_id = auth.uid() AND device_id = p_device_id
  ) INTO is_new;

  INSERT INTO public.user_known_devices (user_id, device_id, last_seen_at)
  VALUES (auth.uid(), p_device_id, now())
  ON CONFLICT (user_id, device_id) DO UPDATE SET last_seen_at = now();

  SELECT count(*) INTO known_count
  FROM public.user_known_devices WHERE user_id = auth.uid();

  -- Only flag when a NEW device shows up for an account that already has at
  -- least one other known device — the user's very first device ever (the
  -- common case, every signup) must never trigger this.
  IF is_new AND known_count > 1 THEN
    INSERT INTO public.device_integrity_events (user_id, device_id, event_type, severity, metadata)
    VALUES (
      auth.uid(), p_device_id, 'multiple_device_access', 'info',
      jsonb_build_object('known_device_count', known_count)
    );
  END IF;

  RETURN jsonb_build_object('is_new_device', is_new, 'known_device_count', known_count);
END;
$$;
