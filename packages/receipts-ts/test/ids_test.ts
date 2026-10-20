import { assertEquals } from "jsr:@std/assert@1.0.19";
import vectors from "../../test-vectors/receipts.json" with { type: "json" };
import { chainNoteId, copiesHash, copyDigest, deviceHash, readerTag } from "../src/ids.ts";
import { explorerTxUrl } from "../src/explorer.ts";

Deno.test("chainNoteId", async () => {
  for (const v of vectors.chainNoteId) assertEquals(await chainNoteId(v.noteId), v.expected);
});

Deno.test("deviceHash", async () => {
  for (const v of vectors.deviceHash) assertEquals(await deviceHash(v.deviceId), v.expected);
});

Deno.test("copyDigest hashes the copy text as UTF-8", async () => {
  for (const v of vectors.copyDigest) {
    assertEquals(await copyDigest(v.saltHex, v.index, v.copyText), v.expected);
  }
});

Deno.test("copiesHash", async () => {
  for (const v of vectors.copiesHash) assertEquals(await copiesHash(v.digests), v.expected);
});

Deno.test("readerTag", async () => {
  for (const v of vectors.readerTag) assertEquals(await readerTag(v), v.expected);
});

Deno.test("explorerTxUrl: devnet has a cluster param, mainnet has none", () => {
  for (const v of vectors.explorerTxUrl) {
    assertEquals(explorerTxUrl(v.signature, v.cluster as "devnet" | "mainnet-beta"), v.expected);
  }
  assertEquals(explorerTxUrl("abc"), "https://explorer.solana.com/tx/abc?cluster=devnet");
});
