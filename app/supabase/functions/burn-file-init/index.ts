// Supabase Edge Function: burn-file-init
//
// First step of the anonymous "Burn Files" upload flow (file.io clone —
// see supabase/migrations/20260710050000_burn_files.sql for the full
// design rationale). Public on purpose (verify_jwt: false) — upload is
// anonymous on both ends by product decision.
//
// POST { declared_size_bytes, expiry_hours? } ->
//   { file_id, signed_upload_url, upload_token }
//
// Responsibilities:
//   1. Check the burn_files_enabled kill-switch.
//   2. Rate-limit by a SALTED HASH of the request IP — never the raw IP,
//      consistent with this app's no-tracking privacy commitment. The hash
//      only lives in burn_file_upload_counters, swept hourly.
//   3. Enforce the size cap (checked again for real in burn-file-confirm,
//      since a client can lie about declared_size_bytes here).
//   4. Insert a `status: 'pending'` row and mint a signed UPLOAD url — the
//      row only becomes usable once burn-file-confirm verifies the object
//      actually landed in Storage.

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

async function hmacHex(message: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const ipSalt = Deno.env.get("BURN_FILES_IP_SALT");
  if (!supabaseUrl || !serviceRoleKey || !ipSalt) {
    return json({ error: "burn-file-init is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const declaredSize = Number(body.declared_size_bytes ?? 0);
  const requestedExpiryHours = body.expiry_hours != null ? Number(body.expiry_hours) : null;
  if (!Number.isFinite(declaredSize) || declaredSize <= 0) {
    return json({ error: "Missing or invalid declared_size_bytes" }, 400);
  }

  // Independent reads — run concurrently instead of paying for two sequential
  // round trips. Order still matters for the rate-limit RPC below: that one
  // stays after the kill-switch check so a disabled feature never burns a
  // caller's quota.
  const [{ data: flag }, { data: configRows }] = await Promise.all([
    admin
      .from("feature_flags")
      .select("is_active")
      .eq("flag_key", "burn_files_enabled")
      .maybeSingle(),
    admin
      .from("remote_configs")
      .select("config_key, config_value")
      .in("config_key", [
        "burn_files_max_size_bytes",
        "burn_files_default_expiry_hours",
        "burn_files_max_expiry_hours",
        "burn_files_rate_limit_per_hour",
        "burn_files_rate_limit_window_minutes",
      ]),
  ]);
  if (flag && flag.is_active === false) {
    return json({ error: "Burn Files is temporarily disabled" }, 503);
  }
  const cfg = (key: string, fallback: number): number => {
    const row = configRows?.find((r: any) => r.config_key === key);
    return row ? Number(row.config_value) : fallback;
  };
  const maxSizeBytes = cfg("burn_files_max_size_bytes", 52428800);
  const defaultExpiryHours = cfg("burn_files_default_expiry_hours", 24);
  const maxExpiryHours = cfg("burn_files_max_expiry_hours", 168);
  const rateLimitPerHour = cfg("burn_files_rate_limit_per_hour", 8);
  const rateLimitWindowMinutes = cfg("burn_files_rate_limit_window_minutes", 60);

  if (declaredSize > maxSizeBytes) {
    return json({ error: `File too large — max ${Math.floor(maxSizeBytes / 1048576)}MB` }, 413);
  }

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const ipHash = await hmacHex(ip, ipSalt);

  const { data: allowed, error: rateErr } = await admin.rpc("check_and_increment_burn_upload_rate", {
    p_ip_hash: ipHash,
    p_limit: rateLimitPerHour,
    p_window_minutes: rateLimitWindowMinutes,
  });
  if (rateErr) {
    console.error("burn-file-init: rate limit check failed", rateErr);
    return json({ error: "Could not process upload request" }, 500);
  }
  if (!allowed) {
    return json({ error: "Too many uploads from this network. Please try again later." }, 429);
  }

  const expiryHours = Math.min(
    requestedExpiryHours && requestedExpiryHours > 0 ? requestedExpiryHours : defaultExpiryHours,
    maxExpiryHours,
  );
  const expiresAt = new Date(Date.now() + expiryHours * 3600 * 1000).toISOString();

  const fileId = crypto.randomUUID();

  const { data: signedUpload, error: uploadErr } = await admin.storage
    .from("burn-files")
    .createSignedUploadUrl(fileId);
  if (uploadErr || !signedUpload) {
    console.error("burn-file-init: failed to create signed upload URL", uploadErr);
    return json({ error: "Could not prepare upload" }, 502);
  }

  const { error: insertErr } = await admin.from("burn_files").insert({
    id: fileId,
    storage_object_key: fileId,
    status: "pending",
    ciphertext_size_bytes: declaredSize,
    expires_at: expiresAt,
  });
  if (insertErr) {
    console.error("burn-file-init: failed to insert row", insertErr);
    return json({ error: "Could not prepare upload" }, 502);
  }

  return json({
    file_id: fileId,
    signed_upload_url: signedUpload.signedUrl,
    upload_token: signedUpload.token,
  });
});
