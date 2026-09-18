// Supabase Edge Function: burn-file-confirm
//
// Second step of the anonymous "Burn Files" upload flow. Called by the
// client immediately after its signed-URL PUT to Storage succeeds.
//
// POST { file_id } -> { ok: true }
//
// Closes a race identified during design review: burn-file-init creates the
// DB row (status: 'pending') and issues a signed upload URL BEFORE the
// client has actually uploaded any bytes. Without this confirm step, a
// burn-file-fetch call could land in that window and "burn" a row whose
// storage object doesn't exist yet. claim_burn_file's `WHERE status = 'ready'`
// gate makes this airtight — nothing is downloadable until this function
// verifies the object is really there.
//
// Also re-checks the REAL uploaded byte size against the size cap — the
// declared_size_bytes given to burn-file-init is client-asserted and could
// lie to dodge the cap; this is the actual enforcement point.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "burn-file-confirm is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const fileId = String(body.file_id ?? "").trim();
  if (!fileId) return json({ error: "Missing file_id" }, 400);

  const { data: row, error: rowErr } = await admin
    .from("burn_files")
    .select("id, storage_object_key, status, ciphertext_size_bytes, expires_at")
    .eq("id", fileId)
    .maybeSingle();
  if (rowErr || !row) return json({ error: "Unknown file_id" }, 404);
  if (row.status !== "pending") return json({ error: "This upload was already confirmed" }, 409);
  if (new Date(row.expires_at).getTime() < Date.now()) {
    return json({ error: "This upload has expired" }, 410);
  }

  // Confirm the object actually exists and get its REAL size — list() with
  // an exact-name search avoids downloading the (possibly large) bytes just
  // to check metadata.
  const { data: listing, error: listErr } = await admin.storage
    .from("burn-files")
    .list("", { search: row.storage_object_key });
  const match = listing?.find((f) => f.name === row.storage_object_key);
  if (listErr || !match) {
    return json({ error: "Upload not found in storage — it may have failed" }, 404);
  }

  const realSize = (match.metadata as { size?: number } | null)?.size ?? 0;

  const { data: configRow } = await admin
    .from("remote_configs")
    .select("config_value")
    .eq("config_key", "burn_files_max_size_bytes")
    .maybeSingle();
  const maxSizeBytes = configRow ? Number(configRow.config_value) : 52428800;

  if (realSize <= 0 || realSize > maxSizeBytes) {
    // Lied about size (or something went wrong) — remove the object and
    // the row rather than leaving an oversized/broken upload in place.
    await admin.storage.from("burn-files").remove([row.storage_object_key]);
    await admin.from("burn_files").delete().eq("id", fileId);
    return json({ error: "Uploaded file exceeds the allowed size" }, 413);
  }

  const { error: updateErr } = await admin
    .from("burn_files")
    .update({ status: "ready", ciphertext_size_bytes: realSize })
    .eq("id", fileId)
    .eq("status", "pending"); // no-op if somehow already confirmed concurrently
  if (updateErr) {
    console.error("burn-file-confirm: failed to mark ready", updateErr);
    return json({ error: "Could not confirm upload" }, 502);
  }

  return json({ ok: true });
});
