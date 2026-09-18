// Supabase Edge Function: cleanup-burn-files
//
// Invoked every 5 minutes by pg_cron via pg_net (see the
// 'burn-files-cleanup-sweep' job in
// supabase/migrations/20260710050000_burn_files.sql) — the actual mechanism
// that makes "permanently deleted" true. pg_cron/raw SQL cannot call the
// Storage REST API directly; this function is the bridge.
//
// Not a public-facing endpoint: gated by a shared secret (x-cron-secret)
// checked against BURN_FILES_CRON_SECRET, since without that check this
// would otherwise be an unauthenticated endpoint anyone could hammer to
// force repeated Storage API calls.
//
// Three deletion cases, matching the migration's design:
//   1. consumed_at more than 5 minutes old — grace window so an
//      already-issued signed download URL isn't cut off mid-transfer.
//   2. expires_at passed and never consumed — the time-based trigger.
//   3. status = 'pending' for 2+ hours — the client never called
//      burn-file-confirm (upload abandoned or failed).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

Deno.serve(async (req: Request) => {
  const cronSecret = Deno.env.get("BURN_FILES_CRON_SECRET");
  if (!cronSecret || req.headers.get("x-cron-secret") !== cronSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "cleanup-burn-files is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const nowIso = new Date().toISOString();
  const fiveMinAgoIso = new Date(Date.now() - 5 * 60 * 1000).toISOString();
  const twoHoursAgoIso = new Date(Date.now() - 2 * 3600 * 1000).toISOString();

  const rowsById = new Map<string, { id: string; storage_object_key: string }>();

  const [consumedGrace, expiredUnconsumed, abandonedPending] = await Promise.all([
    admin.from("burn_files").select("id, storage_object_key")
      .not("consumed_at", "is", null).lt("consumed_at", fiveMinAgoIso),
    admin.from("burn_files").select("id, storage_object_key")
      .eq("status", "ready").is("consumed_at", null).lt("expires_at", nowIso),
    admin.from("burn_files").select("id, storage_object_key")
      .eq("status", "pending").lt("created_at", twoHoursAgoIso),
  ]);

  for (const result of [consumedGrace, expiredUnconsumed, abandonedPending]) {
    if (result.error) {
      console.error("cleanup-burn-files: query failed", result.error);
      continue;
    }
    for (const row of result.data ?? []) rowsById.set(row.id, row);
  }

  const rows = Array.from(rowsById.values());
  let deletedCount = 0;

  for (const batch of chunk(rows, 100)) {
    const keys = batch.map((r) => r.storage_object_key);
    const { error: removeErr } = await admin.storage.from("burn-files").remove(keys);
    if (removeErr) {
      console.error("cleanup-burn-files: storage removal failed for batch", removeErr);
      continue; // don't delete the DB rows if we're not sure the objects are gone
    }
    const { error: deleteErr } = await admin.from("burn_files").delete().in(
      "id",
      batch.map((r) => r.id),
    );
    if (deleteErr) {
      console.error("cleanup-burn-files: row deletion failed for batch", deleteErr);
      continue;
    }
    deletedCount += batch.length;
  }

  return json({ deleted: deletedCount, candidates: rows.length });
});
