// Supabase Edge Function: canary  (NO SUS Canary)
//
// One function, three actions, all POST JSON. Deployed with --no-verify-jwt
// and called with the publishable key, like create-redemption-code.
//
//   { action: "create", note_id, owner_hash, copy_count, copies_hash,
//     expires_in_hours, copies: [{ index, ciphertext, iv }] }
//     -> { seal_tx_hash, seal_solana_sig, expires_at }
//   { action: "open", note_id, device_id, reader_name }
//     -> { copy_index, copy_count, ciphertext, iv, open_tx_hash, open_solana_sig, opened_at }
//   { action: "status", note_id, owner_secret }
//     -> { copy_count, seal_tx_hash, seal_solana_sig, expires_at,
//          copies: [{ copy_index, reader_name, opened_at, open_tx_hash, open_solana_sig }] }
//
// *_solana_sig is the Solana devnet memo signature. *_tx_hash is the Monad
// testnet transaction hash and stays null whenever Monad is off.
//
// Errors: { error: "<safe message>", retry?: true } with a 4xx/5xx status.
//
// The server never sees note text or keys: copies arrive already encrypted
// and the key stays in the link fragment. The chains receive only
// sha256-based ids and hashes (never names or text).
//
// Proof chains (rules in gating.ts):
// - Solana devnet (solana.ts) is the receipt: one SPL Memo per seal and per
//   open. With Monad off a note is sealed only once its Solana memo lands, so
//   a failed seal memo fails `create` with retry: true. A failed open memo is
//   stored as null and sent again on the next open of that copy.
// - Monad testnet is the earlier prototype, kept behind a switch: on only
//   while CANARY_CONTRACT_ADDRESS is set. When on, it runs in parallel with
//   Solana exactly as before (Monad authoritative; a Solana failure only
//   leaves *_solana_sig null). When off: no viem calls, no relayer leases.
// - A note counts as sealed when seal_tx_hash OR seal_solana_sig is set.
// - With neither chain configured, create and open return 503.
//
// Secrets (supabase secrets set ...):
//   CANARY_TAG_SALT          64 hex chars, random, never shared
//   SOLANA_RELAYER_KEYS      comma-separated devnet keypairs (base58 64-byte
//                            secret key or solana-keygen JSON array). Required
//                            while Monad is off; unset = Solana proof off and
//                            responses carry null.
//   SOLANA_RPC_URL           optional, default https://api.devnet.solana.com
//   SOLANA_MEMO_PROGRAM      optional, default MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr
//   CANARY_CONTRACT_ADDRESS  optional; 0x… NoSusCanary on Monad testnet.
//                            Unset or empty = Monad off.
//   CANARY_RELAYER_KEYS      Monad only: comma-separated 0x… private keys (testnet)
//   MONAD_RPC_URL            Monad only, default https://testnet-rpc.monad.xyz
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import {
  createPublicClient,
  createWalletClient,
  defineChain,
  http,
  type Hex,
} from "npm:viem@2.56.5";
import { privateKeyToAccount } from "npm:viem@2.56.5/accounts";
import { loadSolana, openMemo, sealMemo, sendSolanaMemo, type SolanaConfig } from "./solana.ts";
import { isSealed, monadEnabled, planOpen, planSeal } from "./gating.ts";

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

class HttpError extends Error {
  constructor(public status: number, message: string, public retry = false) {
    super(message);
  }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const HEX64_RE = /^[0-9a-f]{64}$/;
const BYTES32_RE = /^0x[0-9a-f]{64}$/;
const IV_RE = /^[0-9a-f]{32}$/;
const PRIVATE_KEY_RE = /^0x[0-9a-fA-F]{64}$/;
const ALLOWED_HOURS = new Set([1, 24, 168]);
const MAX_CIPHERTEXT = 12000;

// Measured in the Hardhat tests: sealNote 73,833 gas, openCopy 78,403 gas.
// Monad charges the gas LIMIT, so keep it explicit and modest.
const GAS_LIMIT = 150_000n;

const CANARY_ABI = [
  {
    type: "function",
    name: "sealNote",
    stateMutability: "nonpayable",
    inputs: [
      { name: "noteId", type: "bytes32" },
      { name: "copyCount", type: "uint16" },
      { name: "copiesHash", type: "bytes32" },
      { name: "expiresAt", type: "uint64" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "openCopy",
    stateMutability: "nonpayable",
    inputs: [
      { name: "noteId", type: "bytes32" },
      { name: "copyIndex", type: "uint16" },
      { name: "readerTag", type: "bytes32" },
    ],
    outputs: [],
  },
] as const;

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new HttpError(503, `canary is not configured (${name})`);
  return value;
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

type Chain = {
  contract: Hex;
  keys: Hex[];
  rpcUrl: string;
};

// Null when Monad is off (CANARY_CONTRACT_ADDRESS unset or empty). Once an
// address is set, a bad Monad config is a 503 as before.
function loadChainOrNull(): Chain | null {
  const contract = (Deno.env.get("CANARY_CONTRACT_ADDRESS") ?? "").trim();
  if (!monadEnabled(contract)) return null;
  if (!/^0x[0-9a-fA-F]{40}$/.test(contract)) {
    throw new HttpError(503, "canary is not configured (contract address)");
  }
  const keys = requireEnv("CANARY_RELAYER_KEYS")
    .split(",")
    .map((k) => k.trim())
    .filter((k) => k.length > 0);
  if (keys.length === 0 || keys.length > 32 || !keys.every((k) => PRIVATE_KEY_RE.test(k))) {
    throw new HttpError(503, "canary is not configured (relayer keys)");
  }
  return {
    contract: contract as Hex,
    keys: keys as Hex[],
    rpcUrl: Deno.env.get("MONAD_RPC_URL") ?? "https://testnet-rpc.monad.xyz",
  };
}

// A bad Solana config is logged and treated as "off". With Monad on, a failed
// memo is logged and stored as null; with Monad off, see handleCreate.
function loadSolanaOrNull(): SolanaConfig | null {
  try {
    return loadSolana();
  } catch (e) {
    console.error("canary: solana is misconfigured", e);
    return null;
  }
}

function requireProofChain(chain: Chain | null, solana: SolanaConfig | null) {
  if (!chain && !solana) {
    throw new HttpError(503, "canary is not configured (no proof chain)");
  }
}

function solanaSig(result: PromiseSettledResult<string | null>, label: string): string | null {
  if (result.status === "fulfilled") return result.value;
  console.error(`${label}: solana memo failed`, result.reason);
  return null;
}

// Sends one contract call from a leased relayer key and waits for success.
// A key is leased for the whole send+confirm so its nonce is never shared.
async function sendCanaryTx(
  admin: SupabaseClient,
  chain: Chain,
  functionName: "sealNote" | "openCopy",
  args: readonly unknown[],
): Promise<Hex> {
  let index: number | null = null;
  for (let attempt = 0; attempt < 40 && index === null; attempt++) {
    const { data, error } = await admin.rpc("canary_lease_relayer", {
      p_count: chain.keys.length,
      p_seconds: 30,
    });
    if (error) throw error;
    if (typeof data === "number") {
      index = data;
    } else {
      await sleep(250);
    }
  }
  if (index === null) {
    throw new HttpError(503, "NO SUS is busy. Try again in a moment.", true);
  }

  try {
    const monadTestnet = defineChain({
      id: 10143,
      name: "Monad Testnet",
      nativeCurrency: { name: "MON", symbol: "MON", decimals: 18 },
      rpcUrls: { default: { http: [chain.rpcUrl] } },
    });
    const account = privateKeyToAccount(chain.keys[index]);
    const wallet = createWalletClient({ account, chain: monadTestnet, transport: http(chain.rpcUrl) });
    const reader = createPublicClient({ chain: monadTestnet, transport: http(chain.rpcUrl) });
    const hash = await wallet.writeContract({
      address: chain.contract,
      abi: CANARY_ABI,
      // deno-lint-ignore no-explicit-any
      functionName: functionName as any,
      // deno-lint-ignore no-explicit-any
      args: args as any,
      gas: GAS_LIMIT,
    });
    const receipt = await reader.waitForTransactionReceipt({
      hash,
      timeout: 20_000,
      pollingInterval: 250,
    });
    if (receipt.status !== "success") {
      throw new Error(`${functionName} reverted in ${hash}`);
    }
    return hash;
  } finally {
    await admin.rpc("canary_release_relayer", { p_index: index });
  }
}

async function handleCreate(admin: SupabaseClient, body: Record<string, unknown>) {
  const noteId = String(body.note_id ?? "");
  const ownerHash = String(body.owner_hash ?? "");
  const copyCount = Number(body.copy_count);
  const copiesHash = String(body.copies_hash ?? "");
  const hours = Number(body.expires_in_hours);
  const copies = Array.isArray(body.copies) ? body.copies : [];

  if (!UUID_RE.test(noteId) || !HEX64_RE.test(ownerHash) || !BYTES32_RE.test(copiesHash)) {
    throw new HttpError(400, "Invalid note.");
  }
  if (!Number.isInteger(copyCount) || copyCount < 2 || copyCount > 100) {
    throw new HttpError(400, "Copy count must be between 2 and 100.");
  }
  if (!ALLOWED_HOURS.has(hours)) throw new HttpError(400, "Invalid expiry.");
  if (copies.length !== copyCount) throw new HttpError(400, "Copy count does not match.");

  const rows = copies.map((raw, position) => {
    const c = raw as Record<string, unknown>;
    const index = Number(c.index);
    const ciphertext = String(c.ciphertext ?? "");
    const iv = String(c.iv ?? "");
    if (
      index !== position || ciphertext.length === 0 || ciphertext.length > MAX_CIPHERTEXT ||
      !IV_RE.test(iv)
    ) {
      throw new HttpError(400, "Invalid copy.");
    }
    return { note_id: noteId, copy_index: index, ciphertext, iv };
  });

  const chain = loadChainOrNull();
  const solana = loadSolanaOrNull();
  requireProofChain(chain, solana);
  const chainNoteId = `0x${await sha256Hex(`nosus-canary:${noteId}`)}`;

  const { data: existing, error: readError } = await admin
    .from("canary_notes")
    .select("owner_hash, seal_tx_hash, seal_solana_sig, expires_at")
    .eq("id", noteId)
    .maybeSingle();
  if (readError) throw readError;

  let expiresAt: string;
  if (existing) {
    if (existing.owner_hash !== ownerHash) throw new HttpError(409, "This note id is taken.");
    expiresAt = existing.expires_at;
  } else {
    expiresAt = new Date(Date.now() + hours * 3600 * 1000).toISOString();
    const { error: noteError } = await admin.from("canary_notes").insert({
      id: noteId,
      owner_hash: ownerHash,
      copy_count: copyCount,
      copies_hash: copiesHash,
      chain_note_id: chainNoteId,
      expires_at: expiresAt,
    });
    if (noteError) throw noteError;
    const { error: copiesError } = await admin.from("canary_copies").insert(rows);
    if (copiesError) {
      await admin.from("canary_notes").delete().eq("id", noteId);
      throw copiesError;
    }
  }

  const expiresAtSeconds = Math.floor(new Date(expiresAt).getTime() / 1000);
  const memo = sealMemo({ note: chainNoteId, copies: copyCount, hash: copiesHash, exp: expiresAtSeconds });
  const sealTxBefore: string | null = existing?.seal_tx_hash ?? null;
  let sealSolana: string | null = existing?.seal_solana_sig ?? null;
  const plan = planSeal({
    monadOn: chain !== null,
    solanaOn: solana !== null,
    sealTx: sealTxBefore,
    sealSolana,
  });

  if (!chain || !plan.monad) {
    // Nothing to send on Monad (Monad is off, or the note is sealed there
    // already); at most the Solana memo is missing.
    if (solana && plan.solana) {
      const [sol] = await Promise.allSettled([sendSolanaMemo(solana, memo)]);
      if (sol.status === "rejected" && plan.solanaRequired) {
        // Solana is the only receipt: no memo means no seal. The row stays, and
        // a retry with the same note id takes the existing-note path.
        console.error("canary create: solana seal failed", sol.reason);
        throw new HttpError(503, "Could not seal the note on Solana. Try again.", true);
      }
      sealSolana = solanaSig(sol, existing ? "canary create (retry)" : "canary create");
      if (sealSolana) {
        await admin.from("canary_notes").update({ seal_solana_sig: sealSolana }).eq("id", noteId);
      }
    }
    if (!isSealed({ seal_tx_hash: sealTxBefore, seal_solana_sig: sealSolana })) {
      // Not reachable while requireProofChain holds; never hand out an unsealed link.
      throw new HttpError(503, "Could not seal the note. Try again.", true);
    }
    return json({ seal_tx_hash: sealTxBefore, seal_solana_sig: sealSolana, expires_at: expiresAt });
  }

  // Monad and Solana in parallel. Monad is authoritative; Solana may fail quietly.
  const [monad, sol] = await Promise.allSettled([
    sendCanaryTx(admin, chain, "sealNote", [chainNoteId, copyCount, copiesHash, BigInt(expiresAtSeconds)]),
    solana && plan.solana ? sendSolanaMemo(solana, memo) : Promise.resolve(sealSolana),
  ]);
  sealSolana = solanaSig(sol, "canary create");
  if (monad.status === "rejected") {
    const e = monad.reason;
    if (e instanceof HttpError) throw e;
    console.error("canary create: seal failed", e);
    throw new HttpError(503, "Could not seal the note on Monad. Try again.", true);
  }
  const sealTx: Hex = monad.value;
  const { error: updateError } = await admin
    .from("canary_notes")
    .update({ seal_tx_hash: sealTx, seal_solana_sig: sealSolana })
    .eq("id", noteId);
  if (updateError) throw updateError;
  return json({ seal_tx_hash: sealTx, seal_solana_sig: sealSolana, expires_at: expiresAt });
}

async function handleOpen(admin: SupabaseClient, body: Record<string, unknown>) {
  const noteId = String(body.note_id ?? "");
  const deviceId = String(body.device_id ?? "");
  const readerName = String(body.reader_name ?? "")
    .replace(/[\x00-\x1F\x7F]/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (!UUID_RE.test(noteId) || !UUID_RE.test(deviceId)) throw new HttpError(400, "Invalid link.");
  if (readerName.length < 1 || readerName.length > 40) {
    throw new HttpError(400, "Type a name between 1 and 40 characters.");
  }

  const { data: note, error: noteError } = await admin
    .from("canary_notes")
    .select("copy_count, chain_note_id, seal_tx_hash, seal_solana_sig, expires_at")
    .eq("id", noteId)
    .maybeSingle();
  if (noteError) throw noteError;
  if (!note || !isSealed(note)) throw new HttpError(404, "This Canary link is not valid.");
  if (new Date(note.expires_at) <= new Date()) throw new HttpError(410, "This Canary link has expired.");

  const tagSalt = requireEnv("CANARY_TAG_SALT");
  const chain = loadChainOrNull();
  const solana = loadSolanaOrNull();
  requireProofChain(chain, solana);
  const deviceHash = await sha256Hex(`device:${deviceId}`);

  let assigned: Record<string, unknown> | null = null;
  for (let attempt = 0; attempt < 2 && assigned === null; attempt++) {
    const { data, error } = await admin.rpc("canary_assign_copy", {
      p_note_id: noteId,
      p_device_hash: deviceHash,
      p_reader_name: readerName,
    });
    if (error) {
      // 23505 = unique violation: a double tap from the same device raced.
      if (error.code === "23505" && attempt === 0) continue;
      throw error;
    }
    assigned = Array.isArray(data) && data.length > 0 ? data[0] : null;
    if (assigned === null) break;
  }
  if (assigned === null) throw new HttpError(409, "Every copy of this note has been opened.");

  const copyIndex = Number(assigned.copy_index);
  const readerTag = `0x${await sha256Hex(`${tagSalt}:${noteId}:${copyIndex}:${deviceHash}`)}`;
  const memo = openMemo({ note: note.chain_note_id, copy: copyIndex, tag: readerTag });
  let openTx = (assigned.open_tx_hash as string | null) ?? null;
  let openSolana = (assigned.open_solana_sig as string | null) ?? null;
  const plan = planOpen({
    monadOn: chain !== null,
    solanaOn: solana !== null,
    noteSealTx: note.seal_tx_hash ?? null,
    openTx,
    openSolana,
  });
  if (chain && plan.monad) {
    // Monad and Solana in parallel. Monad is authoritative; Solana may fail quietly.
    const [monad, sol] = await Promise.allSettled([
      sendCanaryTx(admin, chain, "openCopy", [note.chain_note_id, copyIndex, readerTag]),
      solana && plan.solana ? sendSolanaMemo(solana, memo) : Promise.resolve(openSolana),
    ]);
    openSolana = solanaSig(sol, "canary open");
    if (monad.status === "fulfilled") {
      openTx = monad.value;
    } else {
      const e = monad.reason;
      if (e instanceof HttpError) throw e;
      const message = e instanceof Error ? e.message : String(e);
      if (!message.includes("CopyTaken")) {
        console.error("canary open: chain write failed", e);
        throw new HttpError(503, "Could not record your copy on Monad. Tap to try again.", true);
      }
      // Already on-chain from an earlier attempt whose hash was not stored.
      openTx = null;
    }
    await admin
      .from("canary_copies")
      .update({ reader_tag: readerTag, open_tx_hash: openTx, open_solana_sig: openSolana })
      .eq("note_id", noteId)
      .eq("copy_index", copyIndex);
  } else if (solana && plan.solana) {
    // Nothing to send on Monad (Monad is off, or this copy is recorded there
    // already); only the Solana memo is missing. A failure stays null and is
    // sent again on the next open of this copy.
    const firstOpen = !assigned.reader_tag;
    const [sol] = await Promise.allSettled([sendSolanaMemo(solana, memo)]);
    openSolana = solanaSig(sol, firstOpen ? "canary open" : "canary open (retry)");
    const patch: Record<string, string> = {};
    if (firstOpen) patch.reader_tag = readerTag;
    if (openSolana) patch.open_solana_sig = openSolana;
    if (Object.keys(patch).length > 0) {
      await admin
        .from("canary_copies")
        .update(patch)
        .eq("note_id", noteId)
        .eq("copy_index", copyIndex);
    }
  }

  return json({
    copy_index: copyIndex,
    copy_count: note.copy_count,
    ciphertext: assigned.ciphertext,
    iv: assigned.iv,
    open_tx_hash: openTx,
    open_solana_sig: openSolana,
    opened_at: assigned.opened_at,
  });
}

async function handleStatus(admin: SupabaseClient, body: Record<string, unknown>) {
  const noteId = String(body.note_id ?? "");
  const ownerSecret = String(body.owner_secret ?? "");
  if (!UUID_RE.test(noteId) || !HEX64_RE.test(ownerSecret)) throw new HttpError(400, "Invalid request.");

  const { data: note, error: noteError } = await admin
    .from("canary_notes")
    .select("owner_hash, copy_count, seal_tx_hash, seal_solana_sig, expires_at")
    .eq("id", noteId)
    .maybeSingle();
  if (noteError) throw noteError;
  if (!note) throw new HttpError(404, "Note not found.");
  if ((await sha256Hex(ownerSecret)) !== note.owner_hash) throw new HttpError(403, "Not your note.");

  const { data: copies, error: copiesError } = await admin
    .from("canary_copies")
    .select("copy_index, reader_name, opened_at, open_tx_hash, open_solana_sig")
    .eq("note_id", noteId)
    .not("opened_at", "is", null)
    .order("copy_index");
  if (copiesError) throw copiesError;

  return json({
    copy_count: note.copy_count,
    seal_tx_hash: note.seal_tx_hash,
    seal_solana_sig: note.seal_solana_sig,
    expires_at: note.expires_at,
    copies: copies ?? [],
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const admin = createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"));
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }
    switch (body.action) {
      case "create":
        return await handleCreate(admin, body);
      case "open":
        return await handleOpen(admin, body);
      case "status":
        return await handleStatus(admin, body);
      default:
        return json({ error: "Unknown action" }, 400);
    }
  } catch (e) {
    if (e instanceof HttpError) {
      return json(e.retry ? { error: e.message, retry: true } : { error: e.message }, e.status);
    }
    console.error("canary: unexpected error", e);
    return json({ error: "Something went wrong. Try again.", retry: true }, 500);
  }
});
