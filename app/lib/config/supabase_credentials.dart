/// Configuration file hosting the credentials for the Supabase backend client.
///
/// Leave both [url] and [anonKey] empty to run the application in mock fallback mode.
///
/// To configure, create a `.env` file in the project root or set environment variables:
///   SUPABASE_URL=https://your-project.supabase.co
///   SUPABASE_ANON_KEY=your-anon-key
class SupabaseCredentials {
  static const String url = 'https://ffidvfguojalzpclipzi.supabase.co';

  static const String anonKey = 'sb_publishable_D_mmlb1jjS9Cl6QCuFwEJw_zPAb6kHS';
}
