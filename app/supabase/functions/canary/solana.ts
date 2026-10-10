// Solana devnet proof for NO SUS Canary (the receipt; Monad is optional).
//
// Every seal and every open is written as one SPL Memo on Solana devnet.
// The memo carries the same sha256-based ids and hashes the Monad contract takes, and
// nothing else: never names, note text or keys. While
// SOLANA_RELAYER_KEYS is unset, loadSolana() returns null and nothing here runs
// (index.ts then needs Monad on, or create/open return 503).
//
// Unlike Monad, a Solana transaction is scoped by a recent blockhash, not an
// account nonce, so one relayer key can send concurrently and no lease is needed.
//
// Env (all optional here):
//   SOLANA_RELAYER_KEYS   comma-separated devnet keypairs, each either a base58
//                         64-byte secret key or a solana-keygen JSON array
//   SOLANA_RPC_URL        default https://api.devnet.solana.com
//   SOLANA_MEMO_PROGRAM   default MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr
//                         (SPL Memo: Solana Explorer shows the memo text).
//                         Memo4c2pN8afCj432Lb7RMVKi9PbQnnW7ewFFaV3oAH (p-memo)
//                         is accepted too.

import {
  type Address,
  address,
  appendTransactionMessageInstruction,
  createKeyPairSignerFromBytes,
  createSolanaRpc,
  createTransactionMessage,
  getBase58Encoder,
  getBase64EncodedWireTransaction,
  getSignatureFromTransaction,
  pipe,
  setTransactionMessageFeePayerSigner,
  setTransactionMessageLifetimeUsingBlockhash,
  signTransactionMessageWithSigners,
} from "npm:@solana/kit@8.4.0";
import { Buffer } from "node:buffer";
import {
  getAddMemoInstruction,
  LEGACY_MEMO_PROGRAM_ADDRESS_V3,
  SUPPORTED_MEMO_PROGRAM_ADDRESSES,
} from "npm:@solana-program/memo@0.15.0";

// The Supabase edge runtime resolves @solana/kit's Node build, whose base64
// codec reads the global Buffer that Deno does not define.
(globalThis as { Buffer?: typeof Buffer }).Buffer ??= Buffer;

export type SolanaConfig = {
  rpcUrl: string;
  /** 64-byte secret keys (private key || public key), as solana-keygen writes them. */
  keys: Uint8Array[];
  memoProgram: Address;
};

const BASE58_RE = /^[1-9A-HJ-NP-Za-km-z]+$/;
const BYTES32_RE = /^0x[0-9a-f]{64}$/;
const CONFIRM_TIMEOUT_MS = 20_000;
const CONFIRM_POLL_MS = 400;

// Null when Solana is off. Throws on a bad config (the message never includes
// key material) so the caller can log it and carry on without Solana.
export function loadSolana(): SolanaConfig | null {
  const raw = (Deno.env.get("SOLANA_RELAYER_KEYS") ?? "").trim();
  if (raw === "") return null;

  // Items are comma-separated, but a JSON array item contains commas itself.
  const items = raw.match(/\[[^\]]*\]|[^,\[\]\s]+/g) ?? [];
  const keys = items.map(parseSecretKey);
  if (keys.length === 0 || keys.length > 32) {
    throw new Error("SOLANA_RELAYER_KEYS must hold 1 to 32 keys");
  }

  const memoProgram = (Deno.env.get("SOLANA_MEMO_PROGRAM") ?? "").trim() ||
    LEGACY_MEMO_PROGRAM_ADDRESS_V3;
  if (!(SUPPORTED_MEMO_PROGRAM_ADDRESSES as readonly string[]).includes(memoProgram)) {
    throw new Error("SOLANA_MEMO_PROGRAM is not a known Memo program address");
  }

  return {
    rpcUrl: Deno.env.get("SOLANA_RPC_URL") ?? "https://api.devnet.solana.com",
    keys,
    memoProgram: address(memoProgram),
  };
}

function parseSecretKey(item: string): Uint8Array {
  let bytes: Uint8Array;
  if (item.startsWith("[")) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(item);
    } catch {
      throw new Error("SOLANA_RELAYER_KEYS: a JSON key is not valid JSON");
    }
    if (
      !Array.isArray(parsed) ||
      !parsed.every((n) => Number.isInteger(n) && n >= 0 && n <= 255)
    ) {
      throw new Error("SOLANA_RELAYER_KEYS: a JSON key must be an array of bytes");
    }
    bytes = Uint8Array.from(parsed as number[]);
  } else {
    if (!BASE58_RE.test(item)) {
      throw new Error("SOLANA_RELAYER_KEYS: a key must be base58 or a JSON array");
    }
    bytes = new Uint8Array(getBase58Encoder().encode(item));
  }
  if (bytes.length !== 64) throw new Error("SOLANA_RELAYER_KEYS: a key must be 64 bytes");
  return bytes;
}

function bytes32(name: string, value: string): string {
  if (!BYTES32_RE.test(value)) throw new Error(`memo ${name} must be 0x + 64 hex chars`);
  return value;
}

function uint(name: string, value: number): number {
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`memo ${name} must be a non-negative integer`);
  }
  return value;
}

// {"p":"nosus-canary","v":1,"t":"seal","note":"0x…","copies":N,"hash":"0x…","exp":E}
// exp is unix seconds, 0 when the note never expires.
export function sealMemo(p: { note: string; copies: number; hash: string; exp: number }): string {
  return JSON.stringify({
    p: "nosus-canary",
    v: 1,
    t: "seal",
    note: bytes32("note", p.note),
    copies: uint("copies", p.copies),
    hash: bytes32("hash", p.hash),
    exp: uint("exp", p.exp),
  });
}

// {"p":"nosus-canary","v":1,"t":"open","note":"0x…","copy":N,"tag":"0x…"}
export function openMemo(p: { note: string; copy: number; tag: string }): string {
  return JSON.stringify({
    p: "nosus-canary",
    v: 1,
    t: "open",
    note: bytes32("note", p.note),
    copy: uint("copy", p.copy),
    tag: bytes32("tag", p.tag),
  });
}

// Sends one memo instruction from a random relayer key and waits until the
// transaction is confirmed. Returns the base58 signature. Polls over HTTP; no
// WebSocket subscriptions.
export async function sendSolanaMemo(cfg: SolanaConfig, memo: string): Promise<string> {
  const rpc = createSolanaRpc(cfg.rpcUrl);
  const signer = await createKeyPairSignerFromBytes(
    cfg.keys[Math.floor(Math.random() * cfg.keys.length)],
  );
  const { value: latest } = await rpc.getLatestBlockhash({ commitment: "confirmed" }).send();

  const message = pipe(
    createTransactionMessage({ version: 0 }),
    (m) => setTransactionMessageFeePayerSigner(signer, m),
    (m) => setTransactionMessageLifetimeUsingBlockhash(latest, m),
    (m) =>
      appendTransactionMessageInstruction(
        getAddMemoInstruction({ memo, signers: [signer] }, { programAddress: cfg.memoProgram }),
        m,
      ),
  );
  const transaction = await signTransactionMessageWithSigners(message);
  const signature = getSignatureFromTransaction(transaction);

  await rpc
    .sendTransaction(getBase64EncodedWireTransaction(transaction), {
      encoding: "base64",
      preflightCommitment: "confirmed",
    })
    .send();

  const deadline = Date.now() + CONFIRM_TIMEOUT_MS;
  for (;;) {
    const { value: [status] } = await rpc.getSignatureStatuses([signature]).send();
    if (status?.err) {
      const err = JSON.stringify(status.err, (_, v) => (typeof v === "bigint" ? v.toString() : v));
      throw new Error(`solana memo ${signature} failed: ${err}`);
    }
    if (status?.confirmationStatus === "confirmed" || status?.confirmationStatus === "finalized") {
      return signature;
    }
    if (Date.now() >= deadline) {
      throw new Error(`solana memo ${signature} not confirmed within ${CONFIRM_TIMEOUT_MS} ms`);
    }
    await new Promise((resolve) => setTimeout(resolve, CONFIRM_POLL_MS));
  }
}
