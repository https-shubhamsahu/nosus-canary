// Supabase Edge Function: share-fetch
//
// SecureSend's anonymous door. The ONLY way a share-link recipient (no
// account, no session) ever reaches a file's bytes. Public on purpose
// (verify_jwt: false, same trust model already used by this project's
// drive-proxy function) — the token itself is the credential.
//
// POST { token, viewer_email } ->
//   { file_name, type, signed_url }   (signed_url expires in 5 minutes)
//
// Responsibilities:
//   1. Look up the token (service role — share_links has no public SELECT
//      policy; only this function ever resolves a token to a file).
//   2. Reject revoked / expired / view-limit-exceeded links.
//   3. Reject Google-Drive-linked files (out of scope for v1 — only
//      Supabase-Storage-backed secure_files rows are shareable this way).
//   4. Log the view (viewer_email + timestamp) and bump view_count.
//   5. Mint a short-lived Storage signed URL (service role bypasses RLS for
//      this one call) so the client fetches bytes directly from Supabase's
//      storage CDN — never through this function's response body.
//
// Never logs the token or viewer_email in error output.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SIGNED_URL_TTL_SECONDS = 300; // 5 minutes

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isPlausibleEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

/// A GDrive-linked secure_files row uses its Drive file id as `id`, which
/// never carries the app's own id prefixes (mirrors the check already used in
/// supabase_secure_file_repository.dart's downloadFile/deleteFile).
function isGoogleDriveFile(fileId: string): boolean {
  return !fileId.startsWith("file_") && !fileId.startsWith("sec_gen_");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "share-fetch is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const token = String(body.token ?? "").trim();
  const viewerEmail = String(body.viewer_email ?? "").trim().toLowerCase();
  const deviceType = String(body.device_type ?? "web").trim().toLowerCase();
  if (!token) return json({ error: "Missing token" }, 400);
  if (!viewerEmail || !isPlausibleEmail(viewerEmail)) {
    return json({ error: "A valid email is required to view this document" }, 400);
  }

  // 1. Fetch feature flags to check if SecureSend is enabled and get settings
  const { data: flags, error: flagsErr } = await admin
    .from("feature_flags")
    .select("flag_key, is_active")
    .in("flag_key", [
      "securesend_enabled",
      "securesend_watermark_enforced",
      "securesend_blur_enforced",
    ]);

  if (flagsErr) {
    console.error("share-fetch: Failed to query feature flags", flagsErr);
  }

  const getFlag = (key: string, defaultValue = true): boolean => {
    if (!flags) return defaultValue;
    const f = flags.find((item: any) => item.flag_key === key);
    return f ? f.is_active : defaultValue;
  };

  if (!getFlag("securesend_enabled", true)) {
    return json({ error: "SecureSend sharing is temporarily disabled by administrators" }, 503);
  }

  const watermarkEnforced = getFlag("securesend_watermark_enforced", true);
  const platformAllowsBlur = getFlag("securesend_blur_enforced", true);

  const { data: link, error: linkErr } = await admin
    .from("share_links")
    .select("id, file_id, revoked, expires_at, max_views, view_count, require_touch_reveal")
    .eq("token", token)
    .maybeSingle();

  if (linkErr) return json({ error: "Lookup failed" }, 500);
  if (!link) return json({ error: "This link is invalid" }, 404);
  if (link.revoked) return json({ error: "This link has been revoked" }, 410);
  if (link.expires_at && new Date(link.expires_at).getTime() < Date.now()) {
    return json({ error: "This link has expired" }, 410);
  }
  if (link.max_views != null && link.view_count >= link.max_views) {
    return json({ error: "This link has reached its view limit" }, 410);
  }

  const fileId = link.file_id as string;
  if (isGoogleDriveFile(fileId)) {
    return json({ error: "This file isn't shareable via link yet" }, 400);
  }

  // The sender's own per-link choice AND the platform-wide admin flag both
  // have to allow blur for it to apply — the admin flag is a kill-switch,
  // never a way to force blur ON against what a sender explicitly turned off.
  const blurEnforced = platformAllowsBlur && (link.require_touch_reveal as boolean);


  const { data: file, error: fileErr } = await admin
    .from("secure_files")
    .select("name, type")
    .eq("id", fileId)
    .maybeSingle();
  if (fileErr || !file) return json({ error: "The document could not be found" }, 404);

  const { data: signed, error: signErr } = await admin.storage
    .from("secure-files")
    .createSignedUrl(fileId, SIGNED_URL_TTL_SECONDS);
  if (signErr || !signed?.signedUrl) {
    return json({ error: "The document could not be prepared for viewing" }, 502);
  }

  let viewEventId = null;
  // Log the view + bump the counter. Best-effort: a failure here must not
  // block a legitimate view (the recipient already has a valid signed URL).
  try {
    const { data: eventData } = await admin
      .from("share_view_events")
      .insert({
        link_id: link.id,
        viewer_email: viewerEmail,
        device_type: deviceType === "app" ? "app" : "web",
      })
      .select("id")
      .single();
    
    if (eventData) {
      viewEventId = eventData.id;
    }

    await admin
      .from("share_links")
      .update({ view_count: (link.view_count as number) + 1 })
      .eq("id", link.id);
  } catch (_e) {
    // swallow — see comment above
  }

  return json({
    file_name: file.name,
    type: file.type,
    signed_url: signed.signedUrl,
    watermark_enforced: watermarkEnforced,
    blur_enforced: blurEnforced,
    view_event_id: viewEventId,
  });
});

