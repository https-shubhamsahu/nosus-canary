-- Migration: 20260708000000_share_view_events.sql

CREATE TABLE IF NOT EXISTS public.share_view_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  link_id         UUID NOT NULL REFERENCES public.share_links(id) ON DELETE CASCADE,
  viewer_email    TEXT NOT NULL,
  device_type     TEXT NOT NULL DEFAULT 'web',   -- 'web' | 'app'
  started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_heartbeat  TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at        TIMESTAMPTZ,                   -- set by client on close (best-effort)
  duration_seconds INTEGER GENERATED ALWAYS AS (
    EXTRACT(EPOCH FROM (COALESCE(ended_at, last_heartbeat) - started_at))::INTEGER
  ) STORED
);

-- RLS: only the link's creator (file owner) may read their own events
ALTER TABLE public.share_view_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner can read their link's events" ON public.share_view_events
  FOR SELECT USING (
    link_id IN (
      SELECT id FROM public.share_links WHERE created_by = auth.uid()
    )
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS share_view_events_link_id_idx ON public.share_view_events(link_id);
CREATE INDEX IF NOT EXISTS share_view_events_started_at_idx ON public.share_view_events(started_at DESC);
