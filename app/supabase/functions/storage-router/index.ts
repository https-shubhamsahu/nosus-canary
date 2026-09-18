import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
};

type ProviderConfig = {
  name: string;
  endpoint: string;
  region?: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  freeBytes?: number;
  priority?: number;
};

type StorageObjectRow = {
  user_id: string;
  group_id: string;
  file_id: string;
  provider: string;
  bucket: string;
  object_key: string;
  content_type: string;
};

type AdminClient = any;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const path = url.pathname.split("/").pop();

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return json({
        error: "Storage router Supabase secrets are not configured",
      }, 503);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Invalid or expired session" }, 401);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);
    const userId = userData.user.id;

    if (req.method === "POST" && path === "upload") {
      return await handleUpload(req, url, admin, userId);
    }
    if (req.method === "GET" && path === "download") {
      return await handleDownload(url, admin, userId);
    }
    if (req.method === "DELETE" && path === "delete") {
      return await handleDelete(url, admin, userId);
    }

    return json({ error: "Route not found" }, 404);
  } catch (error) {
    if (error instanceof HttpError) {
      return json({ error: error.message }, error.status);
    }
    return json({
      error: error instanceof Error ? error.message : String(error),
    }, 500);
  }
});

async function handleUpload(
  req: Request,
  url: URL,
  admin: AdminClient,
  userId: string,
): Promise<Response> {
  const providers = loadProviders();
  const groupId = requiredParam(url, "groupId");
  const fileId = requiredParam(url, "fileId");
  const rawName = requiredParam(url, "name");
  const type = url.searchParams.get("type") || "pdf";
  const contentType = url.searchParams.get("contentType") ||
    req.headers.get("content-type") ||
    "application/octet-stream";

  await assertGroupMember(admin, groupId, userId);

  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.byteLength === 0) return json({ error: "Empty upload body" }, 400);

  const provider = await chooseProvider(admin, providers, bytes.byteLength);
  const objectKey = `${userId}/${groupId}/${fileId}`;
  const checksum = await sha256Hex(bytes);
  const logicalPath = `${groupId}/${fileId}`;

  const { error: fileErr } = await admin.from("secure_files").upsert(
    {
      id: fileId,
      group_id: groupId,
      name: rawName,
      type,
      size_bytes: bytes.byteLength,
      is_watermarked: true,
      is_pinned: false,
      security_status: "secured",
      storage_path: fileId,
      uploaded_by: userId,
      owner_id: userId,
    },
    { onConflict: "id" },
  );
  if (fileErr) {
    return json({ error: "Failed to create secure file metadata" }, 500);
  }

  const upload = await s3Fetch(provider, "PUT", objectKey, bytes, contentType);
  if (!upload.ok) {
    const detail = await upload.text();
    await admin.from("secure_files").delete().eq("id", fileId).eq(
      "owner_id",
      userId,
    );
    return json({
      error: "Provider upload failed",
      provider: provider.name,
      detail,
    }, 502);
  }

  const { error: objectErr } = await admin.from("storage_objects").upsert(
    {
      user_id: userId,
      group_id: groupId,
      file_id: fileId,
      logical_path: logicalPath,
      provider: provider.name,
      bucket: provider.bucket,
      object_key: objectKey,
      size_bytes: bytes.byteLength,
      content_type: contentType,
      checksum_sha256: checksum,
      status: "active",
    },
    { onConflict: "file_id" },
  );
  if (objectErr) {
    await s3Fetch(provider, "DELETE", objectKey);
    await admin.from("secure_files").delete().eq("id", fileId).eq(
      "owner_id",
      userId,
    );
    return json({ error: "Failed to create storage index" }, 500);
  }

  return json({
    file_id: fileId,
    provider: provider.name,
    bucket: provider.bucket,
    object_key: objectKey,
    size_bytes: bytes.byteLength,
    checksum_sha256: checksum,
  });
}

async function handleDownload(
  url: URL,
  admin: AdminClient,
  userId: string,
): Promise<Response> {
  const fileId = requiredParam(url, "fileId");
  const row = await loadObjectForAccess(admin, fileId, userId);
  const provider = findProvider(row.provider);

  const upstream = await s3Fetch(provider, "GET", row.object_key);
  if (!upstream.ok) {
    return json(
      { error: "Provider download failed", provider: provider.name },
      502,
    );
  }

  return new Response(upstream.body, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": row.content_type || "application/octet-stream",
      "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
      "Pragma": "no-cache",
    },
  });
}

async function handleDelete(
  url: URL,
  admin: AdminClient,
  userId: string,
): Promise<Response> {
  const fileId = requiredParam(url, "fileId");
  const row = await loadObjectForMutation(admin, fileId, userId);
  const provider = findProvider(row.provider);

  const upstream = await s3Fetch(provider, "DELETE", row.object_key);
  if (!upstream.ok && upstream.status !== 404) {
    return json(
      { error: "Provider delete failed", provider: provider.name },
      502,
    );
  }

  await admin
    .from("storage_objects")
    .update({ status: "deleted" })
    .eq("file_id", fileId);

  return json({ success: true });
}

async function assertGroupMember(
  admin: AdminClient,
  groupId: string,
  userId: string,
) {
  const { data, error } = await admin
    .from("study_group_members")
    .select("user_id")
    .eq("group_id", groupId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error || !data) throw new HttpError("Not a group member", 403);
}

async function loadObjectForAccess(
  admin: AdminClient,
  fileId: string,
  userId: string,
): Promise<StorageObjectRow> {
  const { data: file, error: fileErr } = await admin
    .from("secure_files")
    .select("group_id")
    .eq("id", fileId)
    .maybeSingle();
  if (fileErr || !file) throw new HttpError("File not found", 404);
  await assertGroupMember(admin, file.group_id as string, userId);

  const { data, error } = await admin
    .from("storage_objects")
    .select(
      "user_id, group_id, file_id, provider, bucket, object_key, content_type",
    )
    .eq("file_id", fileId)
    .eq("status", "active")
    .maybeSingle();
  if (error || !data) throw new HttpError("Storage object not found", 404);
  return data as StorageObjectRow;
}

async function loadObjectForMutation(
  admin: AdminClient,
  fileId: string,
  userId: string,
): Promise<StorageObjectRow> {
  const { data: file, error: fileErr } = await admin
    .from("secure_files")
    .select("group_id, owner_id")
    .eq("id", fileId)
    .maybeSingle();
  if (fileErr || !file) throw new HttpError("File not found", 404);

  const groupId = file.group_id as string;
  const isOwner = file.owner_id === userId;
  const { data: adminRow } = await admin
    .from("study_group_members")
    .select("user_id")
    .eq("group_id", groupId)
    .eq("user_id", userId)
    .eq("is_admin", true)
    .maybeSingle();
  if (!isOwner && !adminRow) {
    throw new HttpError("Not allowed to delete object", 403);
  }

  const { data, error } = await admin
    .from("storage_objects")
    .select(
      "user_id, group_id, file_id, provider, bucket, object_key, content_type",
    )
    .eq("file_id", fileId)
    .eq("status", "active")
    .maybeSingle();
  if (error || !data) throw new HttpError("Storage object not found", 404);
  return data as StorageObjectRow;
}

async function chooseProvider(
  admin: AdminClient,
  providers: ProviderConfig[],
  incomingBytes: number,
): Promise<ProviderConfig> {
  const ordered = [...providers].sort((a, b) =>
    (b.priority ?? 0) - (a.priority ?? 0)
  );

  for (const provider of ordered) {
    const used = await usedBytes(admin, provider.name);
    const freeBytes = provider.freeBytes ?? Number.MAX_SAFE_INTEGER;
    if (used + incomingBytes <= freeBytes * 0.8) return provider;
  }

  return ordered[0];
}

async function usedBytes(
  admin: AdminClient,
  providerName: string,
): Promise<number> {
  const { data, error } = await admin
    .from("storage_objects")
    .select("size_bytes")
    .eq("provider", providerName)
    .eq("status", "active");
  if (error || !data) return 0;
  return (data as Array<{ size_bytes?: number | string }>).reduce(
    (total: number, row: { size_bytes?: number | string }) =>
      total + Number(row.size_bytes ?? 0),
    0,
  );
}

function loadProviders(): ProviderConfig[] {
  const raw = Deno.env.get("STORAGE_ROUTER_PROVIDERS");
  if (!raw) {
    throw new HttpError("STORAGE_ROUTER_PROVIDERS is not configured", 503);
  }
  const providers = JSON.parse(raw) as ProviderConfig[];
  if (!Array.isArray(providers) || providers.length === 0) {
    throw new HttpError("No storage providers configured", 503);
  }
  for (const provider of providers) {
    if (
      !provider.name ||
      !provider.endpoint ||
      !provider.bucket ||
      !provider.accessKeyId ||
      !provider.secretAccessKey
    ) {
      throw new HttpError(
        `Invalid provider config: ${provider.name ?? "unknown"}`,
        503,
      );
    }
  }
  return providers;
}

function findProvider(name: string): ProviderConfig {
  const provider = loadProviders().find((item) => item.name === name);
  if (!provider) throw new HttpError(`Provider not configured: ${name}`, 503);
  return provider;
}

async function s3Fetch(
  provider: ProviderConfig,
  method: string,
  objectKey: string,
  body?: Uint8Array,
  contentType = "application/octet-stream",
): Promise<Response> {
  const endpoint = provider.endpoint.replace(/\/+$/, "");
  const url = new URL(`${endpoint}/${provider.bucket}/${encodeKey(objectKey)}`);
  const payloadHash = body ? await sha256Hex(body) : EMPTY_SHA256;
  const headers = await signAwsRequest({
    method,
    url,
    provider,
    payloadHash,
    contentType,
  });

  return await fetch(url, {
    method,
    headers,
    body: method === "PUT" && body ? toArrayBuffer(body) : undefined,
  });
}

async function signAwsRequest(params: {
  method: string;
  url: URL;
  provider: ProviderConfig;
  payloadHash: string;
  contentType: string;
}): Promise<Record<string, string>> {
  const now = new Date();
  const amzDate = toAmzDate(now);
  const dateStamp = amzDate.slice(0, 8);
  const region = params.provider.region || "auto";
  const service = "s3";
  const host = params.url.host;

  const headers: Record<string, string> = {
    "host": host,
    "x-amz-content-sha256": params.payloadHash,
    "x-amz-date": amzDate,
  };
  if (params.method === "PUT") headers["content-type"] = params.contentType;

  const signedHeaders = Object.keys(headers).sort().join(";");
  const canonicalHeaders = Object.keys(headers)
    .sort()
    .map((name) => `${name}:${headers[name]}\n`)
    .join("");
  const canonicalRequest = [
    params.method,
    params.url.pathname,
    "",
    canonicalHeaders,
    signedHeaders,
    params.payloadHash,
  ].join("\n");

  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    await sha256Hex(new TextEncoder().encode(canonicalRequest)),
  ].join("\n");

  const signingKey = await getSignatureKey(
    params.provider.secretAccessKey,
    dateStamp,
    region,
    service,
  );
  const signature = bytesToHex(await hmacBytes(signingKey, stringToSign));

  return {
    ...Object.fromEntries(
      Object.entries(headers).map(([key, value]) => [headerCase(key), value]),
    ),
    "Authorization":
      `AWS4-HMAC-SHA256 Credential=${params.provider.accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
  };
}

async function getSignatureKey(
  secret: string,
  dateStamp: string,
  region: string,
  service: string,
): Promise<Uint8Array> {
  const kDate = await hmacBytes(
    new TextEncoder().encode(`AWS4${secret}`),
    dateStamp,
  );
  const kRegion = await hmacBytes(kDate, region);
  const kService = await hmacBytes(kRegion, service);
  return await hmacBytes(kService, "aws4_request");
}

async function hmacBytes(
  key: Uint8Array,
  message: string,
): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    toArrayBuffer(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      cryptoKey,
      new TextEncoder().encode(message),
    ),
  );
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  return bytesToHex(
    new Uint8Array(await crypto.subtle.digest("SHA-256", toArrayBuffer(bytes))),
  );
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer;
}

function bytesToHex(bytes: Uint8Array): string {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function toAmzDate(date: Date): string {
  return date.toISOString().replace(/[:-]|\.\d{3}/g, "");
}

function encodeKey(key: string): string {
  return key.split("/").map(encodeURIComponent).join("/");
}

function headerCase(name: string): string {
  if (name === "host") return "Host";
  if (name === "content-type") return "Content-Type";
  return name.split("-").map((part) => part[0].toUpperCase() + part.slice(1))
    .join("-");
}

function requiredParam(url: URL, name: string): string {
  const value = url.searchParams.get(name);
  if (!value) throw new HttpError(`Missing ${name}`, 400);
  return value;
}

class HttpError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

const EMPTY_SHA256 =
  "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
