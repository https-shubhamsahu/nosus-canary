-- Security hardening: device-integrity ledger + expanded audit event types
-- for overlay/mirroring/accessibility detection surfaced by the Android
-- device-integrity scanner (root, Frida/Xposed/LSPosed, display mirroring,
-- accessibility-service abuse). See lib/services/device_integrity_service.dart.

-- 1. Expand the audit_logs event_type enum for viewing-context signals that
--    belong in the existing group-scoped, tamper-evident chain — they occur
--    while a specific document is open, same as screenshot_attempt/recording_attempt.
ALTER TABLE public.audit_logs DROP CONSTRAINT IF EXISTS chk_audit_event_type;
ALTER TABLE public.audit_logs ADD CONSTRAINT chk_audit_event_type CHECK (
    event_type IN (
        'file_uploaded',
        'file_downloaded',
        'file_viewed',
        'file_deleted',
        'file_renamed',
        'file_pinned',
        'member_joined',
        'member_left',
        'member_promoted',
        'member_demoted',
        'group_created',
        'group_updated',
        'invite_generated',
        'invite_used',
        'screenshot_attempt',
        'recording_attempt',
        'unauthorized_access',
        'overlay_detected',
        'accessibility_detected',
        'display_mirroring_detected'
    )
);

-- 2. Device-integrity ledger: root/instrumentation findings are a property
--    of the device+user, not of a specific group action, so they get their
--    own append-only, hash-chained table rather than being forced into the
--    group-scoped audit_logs chain. Chained per-user (not per-group).
CREATE TABLE IF NOT EXISTS public.device_integrity_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id text NOT NULL,
    event_type text NOT NULL,
    severity text NOT NULL DEFAULT 'info',
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    previous_hash text NOT NULL,
    entry_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_dievents_metadata_object CHECK (jsonb_typeof(metadata) = 'object'),
    CONSTRAINT chk_dievents_severity CHECK (severity IN ('info', 'warning', 'critical')),
    CONSTRAINT chk_dievents_event_type CHECK (
        event_type IN (
            'root_detected',
            'tamper_detected',
            'device_risk_flagged',
            'session_locked',
            'session_revoked',
            'multiple_device_access',
            'unusual_location_detected'
        )
    )
);

CREATE INDEX IF NOT EXISTS idx_dievents_user_created ON public.device_integrity_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dievents_device ON public.device_integrity_events(device_id);

ALTER TABLE public.device_integrity_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_integrity: self select"
  ON public.device_integrity_events FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- No UPDATE/DELETE policies — append-only by omission, matching audit_logs.
-- No direct INSERT policy either — all writes go through the SECURITY
-- DEFINER RPC below so the hash chain and auth binding can't be bypassed
-- by a client inserting arbitrary rows for another user_id.

CREATE OR REPLACE FUNCTION public.device_integrity_events_hash_trigger()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  prev_hash text;
BEGIN
  SELECT entry_hash INTO prev_hash
  FROM public.device_integrity_events
  WHERE user_id = NEW.user_id AND id != NEW.id
  ORDER BY created_at DESC, id DESC
  LIMIT 1;

  NEW.previous_hash := COALESCE(prev_hash, 'GENESIS');

  NEW.entry_hash := encode(digest(
    NEW.device_id || NEW.event_type || NEW.created_at::text || NEW.previous_hash,
    'sha256'
  ), 'hex');

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_device_integrity_events_hash ON public.device_integrity_events;
CREATE TRIGGER trg_device_integrity_events_hash
  BEFORE INSERT ON public.device_integrity_events
  FOR EACH ROW EXECUTE FUNCTION public.device_integrity_events_hash_trigger();

-- 3. RPC: verify the per-user device-integrity hash chain (mirrors verify_audit_chain)
CREATE OR REPLACE FUNCTION public.verify_device_integrity_chain(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  rec record;
  computed_hash text;
  expected_prev text := 'GENESIS';
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Not authorized to verify another user''s device ledger';
  END IF;

  FOR rec IN
    SELECT * FROM public.device_integrity_events
    WHERE user_id = p_user_id
    ORDER BY created_at ASC, id ASC
  LOOP
    IF rec.previous_hash IS DISTINCT FROM expected_prev THEN
      RETURN jsonb_build_object('status', 'invalid', 'first_broken_record', rec.id, 'reason', 'previous_hash mismatch');
    END IF;

    computed_hash := encode(digest(
      rec.device_id || rec.event_type || rec.created_at::text || rec.previous_hash,
      'sha256'
    ), 'hex');

    IF rec.entry_hash IS DISTINCT FROM computed_hash THEN
      RETURN jsonb_build_object('status', 'invalid', 'first_broken_record', rec.id, 'reason', 'entry_hash mismatch');
    END IF;

    expected_prev := rec.entry_hash;
  END LOOP;

  RETURN jsonb_build_object('status', 'valid');
END;
$$;

-- 4. RPC: log a device-integrity finding (root/instrumentation/risk flag)
--    for the calling user. SECURITY DEFINER so RLS never needs a direct
--    INSERT policy — auth.uid() binds the row server-side.
CREATE OR REPLACE FUNCTION public.log_device_integrity_event(
  p_event_type text,
  p_severity text DEFAULT 'info',
  p_device_id text DEFAULT 'unknown',
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.device_integrity_events (user_id, device_id, event_type, severity, metadata)
  VALUES (auth.uid(), p_device_id, p_event_type, p_severity, p_metadata);

  RETURN true;
END;
$$;
