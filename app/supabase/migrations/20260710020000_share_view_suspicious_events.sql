-- Web-viewer deterrent signals (Phase 2 hardening): the anonymous SecureSend
-- viewer can't prevent screenshots in a browser, but it can now report
-- devtools-open heuristics, repeated tab-visibility switches, and blocked
-- copy/print/save/right-click attempts. These get appended to the existing
-- share_view_events row for that viewing session by the share-heartbeat
-- Edge Function (service role — no client-side INSERT/UPDATE policy needed,
-- matching how heartbeats/close already work).
ALTER TABLE public.share_view_events
  ADD COLUMN IF NOT EXISTS suspicious_events jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.share_view_events.suspicious_events IS
  'Append-only array of {type, at} objects reported by the web viewer (devtools_detected, visibility_hidden_repeated, print_attempted, copy_attempted, right_click_attempted, save_attempted, drag_attempted). Capped at 50 entries server-side in share-heartbeat/index.ts.';
