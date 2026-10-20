// fetchReceipt against saved devnet getTransaction responses. Offline: fetch
// is injected and never reaches the network.
import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.19";
import vectors from "../../test-vectors/receipts.json" with { type: "json" };
import tx2BHqnu from "../../test-vectors/devnet/2BHqnu.json" with { type: "json" };
import txNwoJau from "../../test-vectors/devnet/NwoJau.json" with { type: "json" };
import tx62Frr2 from "../../test-vectors/devnet/62Frr2.json" with { type: "json" };
import tx2b9SS9 from "../../test-vectors/devnet/2b9SS9.json" with { type: "json" };
import tx4NXs89 from "../../test-vectors/devnet/4NXs89.json" with { type: "json" };
import { fetchReceipt } from "../src/fetch.ts";
import { parseReceiptMemo, ReceiptFormatError } from "../src/memo.ts";

const FIXTURES: Record<string, unknown> = {
  "devnet/2BHqnu.json": tx2BHqnu,
  "devnet/NwoJau.json": txNwoJau,
  "devnet/62Frr2.json": tx62Frr2,
  "devnet/2b9SS9.json": tx2b9SS9,
  "devnet/4NXs89.json": tx4NXs89,
};
const SEAL = vectors.devnet[0];
const RPC = "http://rpc.test";

// Returns `body` as the JSON-RPC response and records each request.
function rpc(body: unknown, status = 200) {
  const requests: { url: string; body: unknown }[] = [];
  const fetch = (url: string | URL | Request, init?: RequestInit) => {
    requests.push({ url: String(url), body: JSON.parse(String(init?.body)) });
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  };
  return { fetch: fetch as typeof globalThis.fetch, requests };
}

// A copy of the seal fixture with its single instruction replaced.
function withInstruction(ix: unknown) {
  const copy = structuredClone(tx2BHqnu);
  (copy.result.transaction.message.instructions as unknown[]) = [ix];
  return copy;
}

Deno.test("fetchReceipt decodes every real devnet receipt", async () => {
  for (const v of vectors.devnet) {
    const { fetch } = rpc(FIXTURES[v.fixture]);
    const r = await fetchReceipt(v.signature, { rpcUrl: RPC, fetch });
    assertEquals(r, {
      signature: v.signature,
      slot: v.slot,
      blockTime: v.blockTime,
      feePayer: v.feePayer,
      memoProgram: v.memoProgram,
      receipt: parseReceiptMemo(v.memo),
    });
  }
});

Deno.test("fetchReceipt sends one jsonParsed getTransaction at confirmed", async () => {
  const { fetch, requests } = rpc(tx2BHqnu);
  await fetchReceipt(SEAL.signature, { rpcUrl: RPC, fetch });
  assertEquals(requests, [{
    url: RPC,
    body: {
      jsonrpc: "2.0",
      id: 1,
      method: "getTransaction",
      params: [SEAL.signature, {
        encoding: "jsonParsed",
        maxSupportedTransactionVersion: 0,
        commitment: "confirmed",
      }],
    },
  }]);
});

Deno.test("fetchReceipt reads base58 data from memo programs the node does not parse", async () => {
  const raw = vectors.rawMemoInstruction;
  const { fetch } = rpc(withInstruction({
    accounts: [SEAL.feePayer],
    data: raw.data,
    programId: raw.programId,
    stackHeight: 1,
  }));
  const r = await fetchReceipt(SEAL.signature, { rpcUrl: RPC, fetch });
  assertEquals(r.memoProgram, raw.programId);
  assertEquals(r.receipt, parseReceiptMemo(raw.memo));
});

Deno.test("fetchReceipt errors", async () => {
  const sig = SEAL.signature;
  const memoIx = tx2BHqnu.result.transaction.message.instructions[0];
  const failed = structuredClone(tx2BHqnu);
  (failed.result.meta.err as unknown) = { InstructionError: [0, "Custom"] };
  const cases: [unknown, string, number?][] = [
    [{ jsonrpc: "2.0", result: null, id: 1 }, `transaction ${sig} not found on this cluster`],
    [{ jsonrpc: "2.0", error: { code: -32602, message: "Invalid param" }, id: 1 }, "Invalid param"],
    [{}, "HTTP 503", 503],
    [failed, `transaction ${sig} failed on chain`],
    [
      withInstruction({
        parsed: { type: "transfer", info: {} },
        program: "system",
        programId: "11111111111111111111111111111111",
      }),
      `transaction ${sig} has no memo instruction`,
    ],
    [
      withInstruction({ ...memoIx, parsed: "gm" }),
      `transaction ${sig} memo is not a NO SUS Canary receipt`,
    ],
  ];
  for (const [body, message, status] of cases) {
    const { fetch } = rpc(body, status);
    await assertRejects(() => fetchReceipt(sig, { rpcUrl: RPC, fetch }), Error, message);
  }

  const twice = structuredClone(tx2BHqnu);
  twice.result.transaction.message.instructions.push(memoIx);
  await assertRejects(
    () => fetchReceipt(sig, { rpcUrl: RPC, fetch: rpc(twice).fetch }),
    Error,
    "more than one NO SUS Canary memo",
  );

  const v2 = vectors.invalidMemos.find((v) => v.name === "v=2")!;
  await assertRejects(
    () =>
      fetchReceipt(sig, {
        rpcUrl: RPC,
        fetch: rpc(withInstruction({ ...memoIx, parsed: v2.memo })).fetch,
      }),
    ReceiptFormatError,
    v2.error,
  );

  await assertRejects(
    () => fetchReceipt("not a signature!", { rpcUrl: RPC, fetch: rpc({}).fetch }),
    Error,
    "signature must be a base58 transaction signature",
  );
});
