-- Notifications: per-category preferences, an in-app inbox, and device tokens
-- for push delivery.
--
-- Until this migration the app had no notification system at all. The only
-- thing resembling one was a ScaffoldMessenger SnackBar shown when a share was
-- opened *while the app was already in the foreground* — i.e. visible only to
-- someone who was already looking. AndroidManifest.xml documented the absence
-- and told future contributors not to add POST_NOTIFICATIONS without a real
-- code path; this is that code path.
--
-- Shape: writers never talk to a push provider. They insert a row into
-- `notifications`, which is simultaneously the in-app inbox and the delivery
-- queue. Everything that decides *whether* a person hears about an event is
-- enforced here in the database, so a modified client cannot notify people it
-- should not be able to reach, and cannot suppress a security alert for
-- someone else.

-- ===========================================================================
-- 1. Per-category preferences
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Someone invited you, or asked to join a group you administer.
  invites boolean NOT NULL DEFAULT true,
  -- You were added/removed/banned, or your role changed.
  membership boolean NOT NULL DEFAULT true,
  -- New documents in your groups.
  documents boolean NOT NULL DEFAULT true,
  -- Access revoked, suspicious access, integrity findings. Defaults on and is
  -- the one category worth arguing about before ever defaulting off.
  security boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notification_preferences: self select"
  ON public.notification_preferences FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "notification_preferences: self insert"
  ON public.notification_preferences FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "notification_preferences: self update"
  ON public.notification_preferences FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- ===========================================================================
-- 2. Device tokens
-- ===========================================================================
-- The token is the primary key, not (user_id, token). A push token belongs to
-- an app install, not to a person: when someone signs out and a different
-- account signs in on the same handset, FCM hands back the same token. With a
-- composite key that produces two live rows and the previous account keeps
-- receiving that device's notifications. Keyed on the token, re-registration
-- is an UPSERT that reassigns ownership, which is the correct outcome.
CREATE TABLE IF NOT EXISTS public.device_tokens (
  token text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform text NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  created_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id
  ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- No SELECT policy: a client never needs to read the token list back, and not
-- granting it means a compromised session cannot enumerate the account's other
-- devices. Writes go through the RPCs below.
CREATE POLICY "device_tokens: self delete"
  ON public.device_tokens FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- ===========================================================================
-- 3. The inbox / delivery queue
-- ===========================================================================
-- title and body are written by the enqueue function from fixed templates and
-- deliberately name no document and no group. They are what a push provider
-- receives and what a lock screen renders, and a lock screen is readable by
-- whoever is holding the phone. Context the recipient needs is carried as ids
-- and resolved in-app, behind RLS, after they unlock.
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (category IN ('invites', 'membership', 'documents', 'security')),
  title text NOT NULL,
  body text NOT NULL,
  -- In-app route, e.g. 'group:<id>' or 'audit'. Never a URL with a secret in it.
  deep_link text,
  group_id text REFERENCES public.study_groups(id) ON DELETE CASCADE,
  read_at timestamptz,
  -- Stamped once a push has been handed to the provider, so a delivery sweep
  -- is idempotent and a provider outage does not silently drop notifications.
  pushed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications(user_id, created_at DESC)
  WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_pending_push
  ON public.notifications(created_at)
  WHERE pushed_at IS NULL;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications: self select"
  ON public.notifications FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "notifications: self delete"
  ON public.notifications FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- No INSERT or UPDATE policy on purpose. Inserting is the enqueue function's
-- job (SECURITY DEFINER) — if clients could insert, any account could push
-- arbitrary text to any other account's lock screen. Marking read goes through
-- mark_notifications_read() so `pushed_at` stays out of reach.

-- ===========================================================================
-- 4. Registration / read RPCs
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_token text,
  p_platform text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_token IS NULL OR length(p_token) < 16 OR length(p_token) > 512 THEN
    RAISE EXCEPTION 'Invalid device token';
  END IF;
  IF p_platform NOT IN ('android', 'ios', 'web') THEN
    RAISE EXCEPTION 'Invalid platform';
  END IF;

  INSERT INTO public.device_tokens (token, user_id, platform, last_seen_at)
  VALUES (p_token, v_user_id, p_platform, now())
  ON CONFLICT (token) DO UPDATE
    SET user_id = EXCLUDED.user_id,
        platform = EXCLUDED.platform,
        last_seen_at = now();

  -- First sight of this account: materialise default preferences so the
  -- delivery sweep can join against a real row instead of guessing.
  INSERT INTO public.notification_preferences (user_id)
  VALUES (v_user_id)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$;

-- Sign-out path. Takes the token rather than clearing every token for the
-- account: signing out of one handset must not silence the user's other
-- devices.
CREATE OR REPLACE FUNCTION public.unregister_device_token(p_token text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM public.device_tokens
  WHERE token = p_token AND user_id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_notifications_read(p_ids uuid[] DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.notifications
  SET read_at = now()
  WHERE user_id = v_user_id
    AND read_at IS NULL
    AND (p_ids IS NULL OR id = ANY(p_ids));

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.register_device_token(text, text) FROM public, anon;
REVOKE EXECUTE ON FUNCTION public.unregister_device_token(text) FROM public, anon;
REVOKE EXECUTE ON FUNCTION public.mark_notifications_read(uuid[]) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.register_device_token(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unregister_device_token(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_notifications_read(uuid[]) TO authenticated;

-- ===========================================================================
-- 5. Enqueue
-- ===========================================================================
-- The single writer. Checks the recipient's preference for the category and
-- drops the notification if it is off, so an unwanted category costs nothing
-- downstream and never reaches the inbox either.
--
-- Not callable by clients: the triggers below are SECURITY DEFINER and run as
-- the table owner.
CREATE OR REPLACE FUNCTION public.enqueue_notification(
  p_user_id uuid,
  p_category text,
  p_title text,
  p_body text,
  p_deep_link text DEFAULT NULL,
  p_group_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_enabled boolean;
BEGIN
  IF p_user_id IS NULL THEN RETURN; END IF;

  SELECT CASE p_category
           WHEN 'invites' THEN invites
           WHEN 'membership' THEN membership
           WHEN 'documents' THEN documents
           WHEN 'security' THEN security
         END
    INTO v_enabled
  FROM public.notification_preferences
  WHERE user_id = p_user_id;

  -- No preferences row yet means the account has never opened the app since
  -- this shipped. Default-on matches the column defaults.
  IF v_enabled IS NOT NULL AND v_enabled = false THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications
    (user_id, category, title, body, deep_link, group_id)
  VALUES
    (p_user_id, p_category, p_title, p_body, p_deep_link, p_group_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION
  public.enqueue_notification(uuid, text, text, text, text, text)
  FROM public, anon, authenticated;

-- ===========================================================================
-- 6. Event triggers
-- ===========================================================================
-- Membership changes → tell the person it happened to, and the admins.
CREATE OR REPLACE FUNCTION public.trg_notify_membership()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_admin record;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Admins of the group learn someone arrived. The joiner already knows —
    -- they just tapped the button — so they get nothing.
    FOR v_admin IN
      SELECT user_id FROM public.study_group_members
      WHERE group_id = NEW.group_id AND is_admin = true AND user_id <> NEW.user_id
    LOOP
      PERFORM public.enqueue_notification(
        v_admin.user_id, 'membership',
        'New member', 'Someone joined a group you administer.',
        'group:' || NEW.group_id, NEW.group_id
      );
    END LOOP;
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' AND NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
    PERFORM public.enqueue_notification(
      NEW.user_id, 'membership',
      CASE WHEN NEW.is_admin THEN 'You are now an admin' ELSE 'Your role changed' END,
      CASE WHEN NEW.is_admin
           THEN 'You can now manage members and settings in one of your groups.'
           ELSE 'You no longer have admin rights in one of your groups.' END,
      'group:' || NEW.group_id, NEW.group_id
    );
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    -- Only when someone else did it. Leaving voluntarily is not news.
    IF OLD.user_id <> COALESCE(auth.uid(), OLD.user_id) THEN
      PERFORM public.enqueue_notification(
        OLD.user_id, 'membership',
        'Group access ended',
        'You were removed from a group. Its documents are no longer available to you.',
        'groups', NULL
      );
    END IF;
    RETURN OLD;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS notify_membership ON public.study_group_members;
CREATE TRIGGER notify_membership
  AFTER INSERT OR UPDATE OR DELETE ON public.study_group_members
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_membership();

-- New document → tell the other members. The file name is deliberately absent
-- from the text; it is exactly the kind of thing that should not surface on a
-- lock screen.
CREATE OR REPLACE FUNCTION public.trg_notify_new_document()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_member record;
BEGIN
  FOR v_member IN
    SELECT user_id FROM public.study_group_members
    WHERE group_id = NEW.group_id
      AND user_id <> NEW.uploaded_by
  LOOP
    PERFORM public.enqueue_notification(
      v_member.user_id, 'documents',
      'New document', 'A document was shared in one of your groups.',
      'group:' || NEW.group_id, NEW.group_id
    );
  END LOOP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_new_document ON public.secure_files;
CREATE TRIGGER notify_new_document
  AFTER INSERT ON public.secure_files
  FOR EACH ROW EXECUTE FUNCTION public.trg_notify_new_document();

-- ===========================================================================
-- 7. Housekeeping
-- ===========================================================================
-- Read notifications older than 30 days are not history — the audit log is
-- history. Keeping them only grows the inbox query.
CREATE OR REPLACE FUNCTION public.prune_old_notifications()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_count integer;
BEGIN
  DELETE FROM public.notifications
  WHERE read_at IS NOT NULL AND read_at < now() - interval '30 days';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.prune_old_notifications() FROM public, anon, authenticated;
