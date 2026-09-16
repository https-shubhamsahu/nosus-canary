import "server-only";

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

class BackendNotConfiguredError extends Error {
  constructor() {
    super("The isolated Supabase backend is not configured for this environment.");
  }
}

let adminClient: SupabaseClient | undefined;

export function getExperimentAdmin(): SupabaseClient {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) throw new BackendNotConfiguredError();

  adminClient ??= createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return adminClient;
}

export { BackendNotConfiguredError };
