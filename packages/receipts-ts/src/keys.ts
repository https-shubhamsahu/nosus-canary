// Relayer key parsing, in the SOLANA_RELAYER_KEYS format: comma-separated
// keypairs, each either a base58 64-byte secret key or a solana-keygen JSON
// array. Errors never include key material.

import { base58Decode } from "./base58.ts";

const BASE58_RE = /^[1-9A-HJ-NP-Za-km-z]+$/;

/** 64-byte secret keys (private key || public key), as solana-keygen writes them. */
export function parseRelayerKeys(raw: string): Uint8Array[] {
  // Items are comma-separated, but a JSON array item contains commas itself.
  const items = raw.match(/\[[^\]]*\]|[^,\[\]\s]+/g) ?? [];
  const keys = items.map(parseSecretKey);
  if (keys.length === 0 || keys.length > 32) {
    throw new Error("SOLANA_RELAYER_KEYS must hold 1 to 32 keys");
  }
  return keys;
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
    bytes = base58Decode(item);
  }
  if (bytes.length !== 64) throw new Error("SOLANA_RELAYER_KEYS: a key must be 64 bytes");
  return bytes;
}
