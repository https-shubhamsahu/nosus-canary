// Reads one receipt back from the chain with a plain JSON-RPC getTransaction
// call. No npm packages, so verifying needs nothing but fetch.

import { MEMO_PROGRAM_IDS, parseReceiptMemo, PROTOCOL, type Receipt } from "./memo.ts";
import { base58Decode } from "./base58.ts";
import { DEFAULT_RPC_URLS } from "./explorer.ts";

export type FetchedReceipt = {
  signature: string;
  slot: number;
  /** Unix seconds; null when the node does not know it. */
  blockTime: number | null;
  /** First account key: the relayer that paid for and signed the memo. */
  feePayer: string;
  memoProgram: string;
  receipt: Receipt;
};

type Instruction = { programId: string; parsed?: unknown; data?: string };
type Transaction = {
  slot: number;
  blockTime: number | null;
  meta: { err: unknown } | null;
  transaction: { message: { accountKeys: { pubkey: string }[]; instructions: Instruction[] } };
};

const SIGNATURE_RE = /^[1-9A-HJ-NP-Za-km-z]{64,88}$/;

/**
 * Fetches a transaction and decodes its NO SUS Canary memo. Throws when the
 * transaction is missing or failed, has no memo, has a foreign memo, or the
 * memo is not exactly format v1 (ReceiptFormatError).
 */
export async function fetchReceipt(
  signature: string,
  opts: { rpcUrl?: string; fetch?: typeof fetch } = {},
): Promise<FetchedReceipt> {
  if (!SIGNATURE_RE.test(signature)) {
    throw new Error("signature must be a base58 transaction signature");
  }
  const res = await (opts.fetch ?? fetch)(opts.rpcUrl ?? DEFAULT_RPC_URLS.devnet, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "getTransaction",
      params: [signature, {
        encoding: "jsonParsed",
        maxSupportedTransactionVersion: 0,
        commitment: "confirmed",
      }],
    }),
  });
  if (!res.ok) throw new Error(`getTransaction failed: HTTP ${res.status}`);
  const body = await res.json() as {
    result?: Transaction | null;
    error?: { message?: string };
  };
  if (body.error) throw new Error(`getTransaction failed: ${body.error.message ?? "RPC error"}`);

  const tx = body.result;
  if (!tx) throw new Error(`transaction ${signature} not found on this cluster`);
  if (tx.meta?.err) throw new Error(`transaction ${signature} failed on chain`);

  const memos = tx.transaction.message.instructions
    .filter((ix) => MEMO_PROGRAM_IDS.includes(ix.programId))
    .map((ix) => ({ program: ix.programId, text: memoText(ix) }));
  if (memos.length === 0) throw new Error(`transaction ${signature} has no memo instruction`);
  const ours = memos.filter((m) => m.text.startsWith(`{"p":"${PROTOCOL}",`));
  if (ours.length === 0) {
    throw new Error(`transaction ${signature} memo is not a NO SUS Canary receipt`);
  }
  if (ours.length > 1) {
    throw new Error(`transaction ${signature} has more than one NO SUS Canary memo`);
  }

  return {
    signature,
    slot: tx.slot,
    blockTime: tx.blockTime ?? null,
    feePayer: tx.transaction.message.accountKeys[0]?.pubkey ?? "",
    memoProgram: ours[0].program,
    receipt: parseReceiptMemo(ours[0].text),
  };
}

// RPC nodes decode SPL Memo v1/v3 into `parsed`; other memo programs (p-memo)
// come back as base58 `data`.
function memoText(ix: Instruction): string {
  if (typeof ix.parsed === "string") return ix.parsed;
  if (typeof ix.data === "string") return new TextDecoder().decode(base58Decode(ix.data));
  return "";
}
