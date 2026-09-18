-- RLS initplan optimization + covering FK indexes
--
-- Supabase performance advisor (auth_rls_initplan): bare auth.uid() /
-- auth.role() calls in a policy are re-evaluated per row; wrapping them in a
-- scalar subquery `(select auth.uid())` lets the planner evaluate once per
-- statement. Statements below were generated from pg_policies with only that
-- wrap applied — quals are otherwise byte-identical to production.

alter policy admin_audit_logs_insert_admin on public.admin_audit_logs with check (is_admin((select auth.uid())));
alter policy admin_audit_logs_select_admin on public.admin_audit_logs using (is_admin((select auth.uid())));
alter policy "device_integrity: self select" on public.device_integrity_events using ((user_id = (select auth.uid())));
alter policy feature_flags_write_admin on public.feature_flags using (is_admin((select auth.uid()))) with check (is_admin((select auth.uid())));
alter policy feedback_insert_own on public.feedback with check ((user_id = (select auth.uid())));
alter policy "focus: self all" on public.focus_logs using ((user_id = (select auth.uid()))) with check ((user_id = (select auth.uid())));
alter policy group_invites_write_members on public.group_invites using ((EXISTS ( SELECT 1
   FROM study_group_members
  WHERE ((study_group_members.group_id = group_invites.group_id) AND (study_group_members.user_id = (select auth.uid()))))));
alter policy "Users can insert their own profile" on public.profiles with check (((select auth.uid()) = id));
alter policy "Users can update their own profile" on public.profiles using (((select auth.uid()) = id)) with check (((select auth.uid()) = id));
alter policy remote_configs_write_admin on public.remote_configs using (is_admin((select auth.uid()))) with check (is_admin((select auth.uid())));
alter policy "files: owner or admin delete" on public.secure_files using (((owner_id = (select auth.uid())) OR is_group_admin(group_id)));
alter policy "files: owner or admin update" on public.secure_files using (((owner_id = (select auth.uid())) OR is_group_admin(group_id)));
alter policy "security_alerts: self, group admin, or super admin select" on public.security_alerts using (((user_id = (select auth.uid())) OR is_super_admin((select auth.uid())) OR ((group_id IS NOT NULL) AND is_group_admin(group_id))));
alter policy share_link_views_select_owner on public.share_link_views using ((EXISTS ( SELECT 1
   FROM share_links sl
  WHERE ((sl.id = share_link_views.share_link_id) AND (sl.created_by = (select auth.uid()))))));
alter policy share_links_insert_owner on public.share_links with check (((created_by = (select auth.uid())) AND (EXISTS ( SELECT 1
   FROM secure_files sf
  WHERE ((sf.id = share_links.file_id) AND (sf.owner_id = (select auth.uid())))))));
alter policy share_links_select_own on public.share_links using ((created_by = (select auth.uid())));
alter policy share_links_update_own on public.share_links using ((created_by = (select auth.uid()))) with check ((created_by = (select auth.uid())));
alter policy "owner can read their link's events" on public.share_view_events using ((link_id IN ( SELECT share_links.id
   FROM share_links
  WHERE (share_links.created_by = (select auth.uid())))));
alter policy "members: self delete" on public.study_group_members using ((user_id = (select auth.uid())));
alter policy "members: self insert" on public.study_group_members with check ((user_id = (select auth.uid())));
alter policy "user_known_devices: self select" on public.user_known_devices using ((user_id = (select auth.uid())));
alter policy "notes: self all" on public.user_notes using ((user_id = (select auth.uid()))) with check ((user_id = (select auth.uid())));
alter policy "risk_state: self or super admin select" on public.user_risk_state using (((user_id = (select auth.uid())) OR is_super_admin((select auth.uid()))));
alter policy user_roles_write_super on public.user_roles using (is_super_admin((select auth.uid()))) with check (is_super_admin((select auth.uid())));

-- Covering indexes for FKs flagged by the advisor (unindexed_foreign_keys).
create index if not exists idx_feedback_user_id on public.feedback (user_id);
create index if not exists idx_group_invites_creator_id on public.group_invites (creator_id);
create index if not exists idx_user_risk_state_tier on public.user_risk_state (tier);
