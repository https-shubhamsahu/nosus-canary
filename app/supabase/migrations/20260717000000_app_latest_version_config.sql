-- ===========================================================================
-- APP LATEST VERSION remote config
-- ===========================================================================
-- Source of truth for the in-app "update available" check
-- (lib/features/config/presentation/providers/app_update_provider.dart).
-- The app compares its own PackageInfo version against this row and shows a
-- dismissible update banner + a "GET UPDATE" action in the About modal,
-- opening `app_download_url` (the GitHub releases/latest page, where CI
-- attaches an APK on every v*.*.* tag).
--
-- RELEASE FLOW: bump this row's value after pushing each release tag —
--   UPDATE public.remote_configs
--      SET config_value = '"X.Y.Z"'::jsonb
--    WHERE config_key = 'app_latest_version';
--
-- Unlike other config seeds in this schema history, this uses DO NOTHING
-- rather than DO UPDATE on conflict: the value is expected to move ahead of
-- what any migration says (bumped per release), so replaying migrations must
-- never regress it.

INSERT INTO public.remote_configs (config_key, config_value, description) VALUES
('app_latest_version', '"1.2.0"'::jsonb, 'Latest released app version; drives the in-app update banner. Bump after each release tag.')
ON CONFLICT (config_key) DO NOTHING;
