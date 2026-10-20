// NO SUS Canary receipt memo, format v1 (spec: docs/RECEIPTS_SPEC.md).
//
// One SPL Memo per seal and per open. The memo is compact JSON with a fixed
// key order, so the same receipt is always the same bytes:
//   {"p":"nosus-canary","v":1,"t":"seal","note":"0x…","copies":N,"hash":"0x…","exp":E}
//   {"p":"nosus-canary","v":1,"t":"open","note":"0x…","copy":N,"tag":"0x…"}

export const PROTOCOL = "nosus-canary";
export const VERSION = 1;

/** Longest memo a single-signer transaction can carry. */
export const MAX_MEMO_BYTES = 566;

/** SPL Memo v3 (Solana Explorer shows the memo text). */
export const DEFAULT_MEMO_PROGRAM = "MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr";

/** Memo programs a receipt may be written with: SPL Memo v1, v3 and p-memo. */
export const MEMO_PROGRAM_IDS: readonly string[] = Object.freeze([
  "Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo",
  DEFAULT_MEMO_PROGRAM,
  "Memo4c2pN8afCj432Lb7RMVKi9PbQnnW7ewFFaV3oAH",
]);

export type SealInput = { note: string; copies: number; hash: string; exp: number };
export type OpenInput = { note: string; copy: number; tag: string };
export type SealReceipt = { v: 1; t: "seal" } & SealInput;
export type OpenReceipt = { v: 1; t: "open" } & OpenInput;
export type Receipt = SealReceipt | OpenReceipt;

/** A memo or memo field that is not exactly format v1. */
export class ReceiptFormatError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ReceiptFormatError";
  }
}

const BYTES32_RE = /^0x[0-9a-f]{64}$/;
const SEAL_KEYS = "p,v,t,note,copies,hash,exp";
const OPEN_KEYS = "p,v,t,note,copy,tag";

function bytes32(name: string, value: unknown): string {
  if (typeof value !== "string" || !BYTES32_RE.test(value)) {
    throw new ReceiptFormatError(`memo ${name} must be 0x + 64 hex chars`);
  }
  return value;
}

// Safe integers only, so every encoded memo parses back to the same bytes.
function uint(name: string, value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw new ReceiptFormatError(`memo ${name} must be a non-negative integer`);
  }
  return value;
}

// exp is unix seconds, 0 when the note never expires.
export function encodeSealMemo(p: SealInput): string {
  return JSON.stringify({
    p: PROTOCOL,
    v: VERSION,
    t: "seal",
    note: bytes32("note", p.note),
    copies: uint("copies", p.copies),
    hash: bytes32("hash", p.hash),
    exp: uint("exp", p.exp),
  });
}

export function encodeOpenMemo(p: OpenInput): string {
  return JSON.stringify({
    p: PROTOCOL,
    v: VERSION,
    t: "open",
    note: bytes32("note", p.note),
    copy: uint("copy", p.copy),
    tag: bytes32("tag", p.tag),
  });
}

/**
 * Strict parse: accepts only the exact bytes encodeSealMemo/encodeOpenMemo
 * would write. Throws ReceiptFormatError otherwise.
 */
export function parseReceiptMemo(memo: string): Receipt {
  if (new TextEncoder().encode(memo).length > MAX_MEMO_BYTES) {
    throw new ReceiptFormatError(`memo is longer than ${MAX_MEMO_BYTES} bytes`);
  }
  let m: unknown;
  try {
    m = JSON.parse(memo);
  } catch {
    throw new ReceiptFormatError("memo is not JSON");
  }
  if (typeof m !== "object" || m === null || Array.isArray(m)) {
    throw new ReceiptFormatError("memo is not a JSON object");
  }
  const o = m as Record<string, unknown>;
  if (o.p !== PROTOCOL) throw new ReceiptFormatError(`memo p must be "${PROTOCOL}"`);
  if (o.v !== VERSION) throw new ReceiptFormatError(`memo v must be ${VERSION}`);
  if (o.t !== "seal" && o.t !== "open") {
    throw new ReceiptFormatError('memo t must be "seal" or "open"');
  }

  const keys = o.t === "seal" ? SEAL_KEYS : OPEN_KEYS;
  if (Object.keys(o).join(",") !== keys) {
    throw new ReceiptFormatError(`memo keys must be ${keys} in this order`);
  }

  let receipt: Receipt;
  let canonical: string;
  if (o.t === "seal") {
    receipt = {
      v: 1,
      t: "seal",
      note: bytes32("note", o.note),
      copies: uint("copies", o.copies),
      hash: bytes32("hash", o.hash),
      exp: uint("exp", o.exp),
    };
    canonical = encodeSealMemo(receipt);
  } else {
    receipt = {
      v: 1,
      t: "open",
      note: bytes32("note", o.note),
      copy: uint("copy", o.copy),
      tag: bytes32("tag", o.tag),
    };
    canonical = encodeOpenMemo(receipt);
  }
  // Catches whitespace, 3.0 / 3e0, duplicate keys and anything else that
  // JSON.parse forgives.
  if (canonical !== memo) throw new ReceiptFormatError("memo is not in canonical form");
  return receipt;
}
