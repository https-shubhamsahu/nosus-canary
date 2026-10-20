// Solana devnet receipts for NO SUS Canary.
//
// Every seal and every open is written as one SPL Memo on Solana devnet.
// The memo carries sha256-based ids and hashes and nothing else: never names,
// note text or keys. While SOLANA_RELAYER_KEYS is unset, loadSolana() returns
// null and nothing here runs (create/open then return 503 unless the legacy
// path in index.ts is configured).
//
// The memo format, key parsing and sending live in packages/receipts-ts (spec:
// docs/RECEIPTS_SPEC.md). This file only reads the env and keeps the names
// index.ts imports.
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
  DEFAULT_MEMO_PROGRAM,
  encodeOpenMemo,
  encodeSealMemo,
  MEMO_PROGRAM_IDS,
  parseRelayerKeys,
  type SendConfig,
  sendMemo,
} from "../../../../packages/receipts-ts/mod.ts";

export type SolanaConfig = SendConfig;

// Null when Solana is off. Throws on a bad config (the message never includes
// key material) so the caller can log it and carry on without Solana.
export function loadSolana(): SolanaConfig | null {
  const raw = (Deno.env.get("SOLANA_RELAYER_KEYS") ?? "").trim();
  if (raw === "") return null;
  const keys = parseRelayerKeys(raw);

  const memoProgram = (Deno.env.get("SOLANA_MEMO_PROGRAM") ?? "").trim() || DEFAULT_MEMO_PROGRAM;
  if (!MEMO_PROGRAM_IDS.includes(memoProgram)) {
    throw new Error("SOLANA_MEMO_PROGRAM is not a known Memo program address");
  }

  return {
    rpcUrl: Deno.env.get("SOLANA_RPC_URL") ?? "https://api.devnet.solana.com",
    keys,
    memoProgram,
  };
}

// {"p":"nosus-canary","v":1,"t":"seal","note":"0x…","copies":N,"hash":"0x…","exp":E}
// exp is unix seconds, 0 when the note never expires.
export const sealMemo = encodeSealMemo;

// {"p":"nosus-canary","v":1,"t":"open","note":"0x…","copy":N,"tag":"0x…"}
export const openMemo = encodeOpenMemo;

// Sends one memo from a random relayer key and waits until it is confirmed.
// Returns the base58 signature.
export function sendSolanaMemo(cfg: SolanaConfig, memo: string): Promise<string> {
  return sendMemo(cfg, { memo });
}
