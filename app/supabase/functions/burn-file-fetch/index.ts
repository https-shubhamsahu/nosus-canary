// Supabase Edge Function: burn-file-fetch
//
// The recipient's ONLY path to a Burn File's bytes. Public on purpose
// (verify_jwt: false) — the recipient never has an account, exactly like
// the SecureSend anonymous viewer, but with no email gate: single tap,
// zero friction, matching real file.io.
//
// POST { file_id } -> { signed_url } | 410 if already downloaded/expired
//
// Deletion of the file is a TWO-STAGE process, not something this function
// does directly:
//   1. claim_burn_file() atomically marks consumed_at the moment this
//      resolves successfully — a second call with the same file_id always
//      gets 410 from here on, even if the actual bytes aren't wiped yet.
//   2. The cleanup-burn-files cron sweep (every 5 minutes) removes the
//      actual storage object after a grace window past consumed_at, so an
//      already-issued signed URL isn't yanked out from under an in-flight
//      download.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SIGNED_URL_TTL_SECONDS = 300; // 5 minutes — same TTL SecureSend's share-fetch uses

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
    return json({ error: "burn-file-fetch is not configured" }, 503);
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

  const { data: flag } = await admin
    .from("feature_flags")
    .select("is_active")
    .eq("flag_key", "burn_files_enabled")
    .maybeSingle();
  if (flag && flag.is_active === false) {
    return json({ error: "Burn Files is temporarily disabled" }, 503);
  }

  const { data: claimed, error: claimErr } = await admin.rpc("claim_burn_file", { p_id: fileId });
  if (claimErr) {
    console.error("burn-file-fetch: claim RPC failed", claimErr);
    return json({ error: "Could not process this link" }, 500);
  }
  if (!claimed?.id) {
    return json({ error: "This file has already been downloaded, expired, or does not exist" }, 410);
  }

  const { data: signed, error: signErr } = await admin.storage
    .from("burn-files")
    .createSignedUrl(claimed.storage_object_key, SIGNED_URL_TTL_SECONDS);
  if (signErr || !signed?.signedUrl) {
    console.error("burn-file-fetch: failed to sign download URL", signErr);
    return json({ error: "The file could not be prepared for download" }, 502);
  }

  return json({ signed_url: signed.signedUrl });
});
