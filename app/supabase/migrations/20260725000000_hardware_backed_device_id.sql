-- Supports moving the client's device identity from a random UUID held in
-- SharedPreferences to a digest of a non-extractable Android Keystore key
-- (android/app/.../security/KeyAttestationManager.kt).
--
-- Why this function has to exist at all: the id format changes, so on first
-- launch after the upgrade every already-known device would look brand new to
-- register_device_seen(). That fires 'multiple_device_access' for every user
-- who has ever signed in on more than one device — a flood of false findings
-- in the integrity ledger on upgrade day. This renames the row in place and
-- carries first_seen_at across so the device stays "known".
--
-- Deliberately does NOT touch device_integrity_events. That table is an
-- append-only hash chain whose entry_hash is computed over device_id by a
-- BEFORE INSERT trigger (20260710010000_security_hardening.sql); an UPDATE
-- would not recompute it, so rewriting historical device_ids there would
-- silently break verify_device_integrity_chain(). Past findings correctly
-- stay recorded against the id that was current when they were observed.

CREATE OR REPLACE FUNCTION public.migrate_device_id(
  p_old_device_id text,
  p_new_device_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old_first_seen timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_old_device_id IS NULL
     OR p_new_device_id IS NULL
     OR p_old_device_id = p_new_device_id THEN
    RETURN jsonb_build_object('migrated', false, 'reason', 'noop');
  END IF;

  SELECT first_seen_at INTO v_old_first_seen
  FROM public.user_known_devices
  WHERE user_id = auth.uid() AND device_id = p_old_device_id;

  -- Nothing to carry over: a fresh install, or already migrated. The caller
  -- then just registers the new id normally, which is the correct outcome.
  IF v_old_first_seen IS NULL THEN
    RETURN jsonb_build_object('migrated', false, 'reason', 'no_legacy_row');
  END IF;

  -- Upsert rather than UPDATE ... SET device_id: the new id may already be
  -- present (a retried migration, or the same hardware id arriving from a
  -- reinstall), and that would collide with the (user_id, device_id) PK.
  INSERT INTO public.user_known_devices (user_id, device_id, first_seen_at, last_seen_at)
  VALUES (auth.uid(), p_new_device_id, v_old_first_seen, now())
  ON CONFLICT (user_id, device_id) DO UPDATE
    SET first_seen_at = LEAST(user_known_devices.first_seen_at, EXCLUDED.first_seen_at),
        last_seen_at  = now();

  DELETE FROM public.user_known_devices
  WHERE user_id = auth.uid() AND device_id = p_old_device_id;

  RETURN jsonb_build_object('migrated', true);
END;
$$;

-- Same least-privilege posture as every other RPC here
-- (20260711000000_function_grants_least_privilege.sql): authenticated only,
-- and the function derives the user from auth.uid() rather than trusting a
-- caller-supplied user_id, so one user can never rewrite another's devices.
revoke execute on function public.migrate_device_id(text, text) from public, anon;
grant  execute on function public.migrate_device_id(text, text) to authenticated;
