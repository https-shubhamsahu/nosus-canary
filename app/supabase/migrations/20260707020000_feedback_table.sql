-- Migration: 20260707020000_feedback_table.sql
-- The profile screen's "Help & Feedback" form previously showed a success
-- toast without sending anything anywhere. This gives it a real destination.
-- Users can INSERT their own feedback; there is deliberately no SELECT/UPDATE/
-- DELETE policy for regular users — submissions are read by the founder via
-- the dashboard (service role bypasses RLS).

CREATE TABLE IF NOT EXISTS public.feedback (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  message     TEXT NOT NULL CHECK (length(message) BETWEEN 1 AND 2000),
  app_version TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feedback_insert_own" ON public.feedback
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
