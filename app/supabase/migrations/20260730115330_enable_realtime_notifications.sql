-- Fix for 20260730112523_notifications: the table was created but never added
-- to the realtime publication.
--
-- NotificationRepository.watchInbox() subscribes with `.stream(primaryKey:
-- ['id'])`, and that is the only live path — fetchInbox() is used for the
-- initial load, nothing polls afterwards. Without the table in
-- `supabase_realtime` the subscription fails outright:
--
--   NO SUS: Notification stream error: RealtimeSubscribeException(
--     status: channelError, ... table: notifications ...)
--
-- observed on a real device (OnePlus CPH2487, Android 16) on 2026-07-30. The
-- inbox would show whatever existed at launch and never move again — a
-- notification system that silently stops notifying.
--
-- Same guarded DO-block shape the rest of this repo uses (see
-- 20260704000000_fhe_subsystem.sql), so a re-run and a local stack without the
-- publication both stay no-ops rather than errors.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    EXCEPTION WHEN duplicate_object THEN
      NULL; -- already added
    END;
  END IF;
END $$;

-- RLS still applies to realtime: "notifications: self select" is what stops the
-- subscription delivering another account's rows. The `.eq('user_id', …)` in
-- the Dart client is defence in depth, not the boundary.
