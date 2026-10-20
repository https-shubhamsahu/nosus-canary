// The sha256-based ids and hashes a receipt carries. Inputs are hashed as
// UTF-8 text; outputs are lowercase hex. Same formulas as the Canary app and
// the edge function, so anyone can recompute them.

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** The memo `note`: "0x" + sha256("nosus-canary:" + noteId). noteId is a lowercase UUID. */
export async function chainNoteId(noteId: string): Promise<string> {
  return `0x${await sha256Hex(`nosus-canary:${noteId}`)}`;
}

/** sha256("device:" + deviceId), no 0x. Only ever stored or hashed again, never on chain. */
export function deviceHash(deviceId: string): Promise<string> {
  return sha256Hex(`device:${deviceId}`);
}

/**
 * The open memo `tag`: "0x" + sha256("<tagSalt>:<noteId>:<copyIndex>:<deviceHash>").
 * tagSalt is the relayer's secret, so only the relayer can recompute it.
 */
export async function readerTag(
  p: { tagSalt: string; noteId: string; copyIndex: number; deviceHash: string },
): Promise<string> {
  return `0x${await sha256Hex(`${p.tagSalt}:${p.noteId}:${p.copyIndex}:${p.deviceHash}`)}`;
}

/** Commitment to one copy: sha256("<saltHex>:<index>:<copyText>"), no 0x. */
export function copyDigest(saltHex: string, index: number, copyText: string): Promise<string> {
  return sha256Hex(`${saltHex}:${index}:${copyText}`);
}

/** The seal memo `hash`: "0x" + sha256 of the copy digests joined in copy order. */
export async function copiesHash(copyDigests: string[]): Promise<string> {
  return `0x${await sha256Hex(copyDigests.join(""))}`;
}
