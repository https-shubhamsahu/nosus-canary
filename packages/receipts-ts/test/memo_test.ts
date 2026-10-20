import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.19";
import vectors from "../../test-vectors/receipts.json" with { type: "json" };
import {
  encodeOpenMemo,
  encodeSealMemo,
  MAX_MEMO_BYTES,
  parseReceiptMemo,
  ReceiptFormatError,
} from "../src/memo.ts";

Deno.test("seal memos encode to the exact vector bytes and parse back", () => {
  for (const v of vectors.sealMemo) {
    assertEquals(encodeSealMemo(v.input), v.memo, v.name);
    assertEquals(parseReceiptMemo(v.memo), { v: 1, t: "seal", ...v.input }, v.name);
  }
});

Deno.test("open memos encode to the exact vector bytes and parse back", () => {
  for (const v of vectors.openMemo) {
    assertEquals(encodeOpenMemo(v.input), v.memo, v.name);
    assertEquals(parseReceiptMemo(v.memo), { v: 1, t: "open", ...v.input }, v.name);
  }
});

Deno.test("the largest memo today is 219 bytes", () => {
  const sizes = [...vectors.sealMemo, ...vectors.openMemo].map((v) =>
    new TextEncoder().encode(v.memo).length
  );
  assertEquals(Math.max(...sizes), 219);
});

Deno.test("encoders reject bad fields with the shared messages", () => {
  for (const v of vectors.encodeErrors) {
    const encode = v.kind === "seal"
      ? () => encodeSealMemo(v.input as Parameters<typeof encodeSealMemo>[0])
      : () => encodeOpenMemo(v.input as Parameters<typeof encodeOpenMemo>[0]);
    assertThrows(encode, ReceiptFormatError, v.error, v.name);
  }
});

Deno.test("parseReceiptMemo rejects every invalid vector with the shared message", () => {
  for (const v of vectors.invalidMemos) {
    const err = assertThrows(() => parseReceiptMemo(v.memo), ReceiptFormatError);
    assertEquals(err.message, v.error, v.name);
  }
});

Deno.test("MAX_MEMO_BYTES matches the vectors", () => {
  assertEquals(MAX_MEMO_BYTES, vectors.maxMemoBytes);
});
