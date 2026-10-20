// Base58 (Bitcoin alphabet) to bytes. Kept local so parsing keys and reading
// receipts never load @solana/kit; only send.ts does.

const ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

export function base58Decode(text: string): Uint8Array {
  let n = 0n;
  for (const c of text) {
    const digit = ALPHABET.indexOf(c);
    if (digit < 0) throw new Error("not base58");
    n = n * 58n + BigInt(digit);
  }
  const bytes: number[] = [];
  for (; n > 0n; n >>= 8n) bytes.unshift(Number(n & 0xffn));
  // Each leading "1" is a leading zero byte.
  for (const c of text) {
    if (c !== "1") break;
    bytes.unshift(0);
  }
  return Uint8Array.from(bytes);
}
