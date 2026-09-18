-- Product analytics: the activation funnel, and nothing else.
--
-- This is the first surface in NO SUS that collects anything for the team's
-- benefit rather than the user's, so the constraints are enforced by the
-- schema rather than left to client discipline:
--
--   * `event` is checked against a fixed allowlist. A new event name requires a
--     migration, which is the point — it makes "just log one more thing" a
--     reviewed decision instead of a one-line client change.
--   * `properties` is capped at 2KB and must be a JSON object. It is for low-
--     cardinality context (which tab, which platform), never document names,
--     group names, file contents, invite codes or link tokens.
--   * Nobody can read their own rows back, let alone anyone else's. SELECT is
--     admin-only; the client is write-only.
--
-- Turning this on changes the Play Data Safety answers — see
-- store_listing/data_safety_answers.md, updated in the same commit.

CREATE TABLE IF NOT EXISTS public.analytics_events (
  id bigserial PRIMARY KEY,
  -- Nullable: the most important events in an activation funnel happen before
  -- there is an account. ON DELETE SET NULL so deleting an account detaches its
  -- history rather than leaving a dangling reference or blocking the delete.
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event text NOT NULL,
  properties jsonb NOT NULL DEFAULT '{}'::jsonb,
  app_version text,
  platform text,
  created_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT analytics_events_event_allowed CHECK (event IN (
    'app_opened',
    'welcome_viewed',
    'guest_tool_opened',
    'auth_wall_hit',
    'signup_started',
    'signup_completed',
    'signin_completed',
    'onboarding_started',
    'onboarding_skipped',
    'onboarding_completed',
    'intent_resumed',
    'group_create_started',
    'group_create_completed',
    'group_join_started',
    'group_join_completed',
    'first_document_uploaded',
    'first_document_viewed',
    'burn_note_created',
    'burn_file_created',
    'notification_permission_prompted',
    'notification_permission_granted',
    'notification_permission_denied',
    'tour_step_shown',
    'tour_skipped',
    'help_topic_opened'
  )),
  CONSTRAINT analytics_events_properties_is_object
    CHECK (jsonb_typeof(properties) = 'object'),
  CONSTRAINT analytics_events_properties_small
    CHECK (pg_column_size(properties) <= 2048),
  CONSTRAINT analytics_events_platform_short
    CHECK (platform IS NULL OR length(platform) <= 32),
  CONSTRAINT analytics_events_version_short
    CHECK (app_version IS NULL OR length(app_version) <= 32)
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_event_created
  ON public.analytics_events (event, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_events_user
  ON public.analytics_events (user_id) WHERE user_id IS NOT NULL;

ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- Signed-in writes must be attributed to the caller — a client cannot forge
-- another user's funnel.
CREATE POLICY analytics_events_insert_authenticated
  ON public.analytics_events FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

-- Signed-out writes must be anonymous. Without the null check, an unauthenticated
-- caller could attribute events to any user id it could guess.
CREATE POLICY analytics_events_insert_anon
  ON public.analytics_events FOR INSERT TO anon
  WITH CHECK (user_id IS NULL);

CREATE POLICY analytics_events_select_admin
  ON public.analytics_events FOR SELECT TO authenticated
  USING (public.is_admin((SELECT auth.uid())));

-- No UPDATE or DELETE policy: events are append-only from every client role.

COMMENT ON TABLE public.analytics_events IS
  'Activation-funnel events. Write-only from clients, admin-readable. Never '
  'store document names, group names, file contents, invite codes or share '
  'tokens in `properties` — see the allowlist constraint and '
  'store_listing/data_safety_answers.md.';
