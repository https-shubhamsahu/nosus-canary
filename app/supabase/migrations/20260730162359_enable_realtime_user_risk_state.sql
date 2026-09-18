-- Migration: 20260730162359_enable_realtime_user_risk_state.sql
-- watchMyRiskState subscribes to public.user_risk_state, but the table was
-- never added to the supabase_realtime publication, so every subscribe failed
-- with RealtimeSubscribeException(status: channelError). Mirrors the existing
-- enable_realtime_share_view_events / enable_realtime_notifications migrations.
--
-- REPLICA IDENTITY FULL so the `user_id=eq.<uuid>` filter still matches on
-- DELETE; with the default identity a delete only carries the primary key and
-- would be dropped by the filter before reaching the client. RLS on the table
-- already restricts rows to `user_id = auth.uid() OR is_super_admin(auth.uid())`,
-- so streaming does not widen visibility.
--
-- Applied to the live project on 2026-07-30 as version 20260730162359.

alter table public.user_risk_state replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_risk_state'
  ) then
    alter publication supabase_realtime add table public.user_risk_state;
  end if;
end $$;
