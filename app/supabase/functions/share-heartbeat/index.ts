// Supabase Edge Function: share-heartbeat
//
// Receives periodic heartbeats from recipients viewing documents to update
// their last active timestamp or mark the session as ended.
//
// POST { view_event_id, close, event_type? } -> { ok: true }
//
// event_type (optional): a web-viewer deterrent signal — devtools opened,
// repeated tab-visibility switches, or a blocked copy/print/save/right-click
// attempt (see lib/services/web_security_guard.dart). Appended to
// share_view_events.suspicious_events, capped at MAX_SUSPICIOUS_EVENTS so a
// hostile client spamming this endpoint can't grow the row unbounded.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const ALLOWED_EVENT_TYPES = new Set([
  "devtools_detected",
  "visibility_hidden_repeated",
  "print_attempted",
  "copy_attempted",
  "right_click_attempted",
  "save_attempted",
  "drag_attempted",
  "automation_detected",
]);

const MAX_SUSPICIOUS_EVENTS = 50;

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
    return json({ error: "share-heartbeat is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const eventId = String(body.view_event_id ?? "").trim();
  const isClose = !!body.close;
  const eventType = body.event_type != null ? String(body.event_type).trim() : null;

  if (!eventId) return json({ error: "Missing view_event_id" }, 400);
  if (eventType && !ALLOWED_EVENT_TYPES.has(eventType)) {
    return json({ error: "Unknown event_type" }, 400);
  }

  try {
    if (isClose) {
      await admin
        .from("share_view_events")
        .update({ ended_at: new Date().toISOString() })
        .eq("id", eventId);
    } else {
      await admin
        .from("share_view_events")
        .update({ last_heartbeat: new Date().toISOString() })
        .eq("id", eventId);
    }

    if (eventType) {
      // Read-modify-write rather than a raw jsonb-append expression: this
      // endpoint runs at most a few times per minute per viewer, so the
      // extra round trip is cheap and keeps the capping logic simple.
      const { data: row } = await admin
        .from("share_view_events")
        .select("suspicious_events")
        .eq("id", eventId)
        .maybeSingle();

      const existing = Array.isArray(row?.suspicious_events) ? row!.suspicious_events : [];
      const next = [...existing, { type: eventType, at: new Date().toISOString() }]
        .slice(-MAX_SUSPICIOUS_EVENTS);

      await admin
        .from("share_view_events")
        .update({ suspicious_events: next })
        .eq("id", eventId);
    }
  } catch (e) {
    console.error("share-heartbeat: Failed to update heartbeat", e);
    return json({ error: "Failed to update heartbeat" }, 500);
  }

  return json({ ok: true });
});
