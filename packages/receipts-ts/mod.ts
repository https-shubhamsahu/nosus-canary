/**
 * NO SUS Canary receipts: encode, parse, send and fetch the SPL Memo that
 * records each seal and each open on Solana. Spec: docs/RECEIPTS_SPEC.md.
 *
 * ```ts
 * import { explorerTxUrl, fetchReceipt } from "@nosus/receipts";
 *
 * const r = await fetchReceipt("2BHqnu…");
 * console.log(r.receipt, explorerTxUrl(r.signature));
 * ```
 *
 * @module
 */

export {
  DEFAULT_MEMO_PROGRAM,
  encodeOpenMemo,
  encodeSealMemo,
  MAX_MEMO_BYTES,
  MEMO_PROGRAM_IDS,
  type OpenInput,
  type OpenReceipt,
  parseReceiptMemo,
  PROTOCOL,
  type Receipt,
  ReceiptFormatError,
  type SealInput,
  type SealReceipt,
  VERSION,
} from "./src/memo.ts";
export { chainNoteId, copiesHash, copyDigest, deviceHash, readerTag } from "./src/ids.ts";
export { parseRelayerKeys } from "./src/keys.ts";
export { type SendConfig, sendMemo } from "./src/send.ts";
export { type FetchedReceipt, fetchReceipt } from "./src/fetch.ts";
export { type Cluster, DEFAULT_RPC_URLS, explorerTxUrl } from "./src/explorer.ts";
