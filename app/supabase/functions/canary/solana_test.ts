// Offline checks that solana.ts still writes the exact memos already on
// devnet, and that loadSolana keeps its defaults and messages. Run from the
// repo root (env access: loadSolana reads SOLANA_*, and @solana/kit's `ws`
// dependency reads WS_* at import):
//   npx -y deno@2 test --allow-env app/supabase/functions/canary/solana_test.ts
import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.19";
import {
  LEGACY_MEMO_PROGRAM_ADDRESS_V3,
  SUPPORTED_MEMO_PROGRAM_ADDRESSES,
} from "npm:@solana-program/memo@0.15.0";
import { MEMO_PROGRAM_IDS } from "../../../../packages/receipts-ts/mod.ts";
import { loadSolana, openMemo, sealMemo } from "./solana.ts";

const NOTE_A = "0xe5bbe8d0602b1dfda55ea516343e6a5064d021c37e6b7ba648bc5719aea1fc40";
const NOTE_B = "0x56f7956802f494824332309f033188a8850e78b4aed1eca6b1d923534315831d";

Deno.test("sealMemo writes the exact devnet seal memos", () => {
  // 2BHqnuCxYyemfegHkncgTsQyMPjpyB9boD1XqYfD1Wtbcf51Fpy3y264UwGhnvRKtcxFKCaSAzHxLrDwFRk512bQ
  assertEquals(
    sealMemo({
      note: NOTE_A,
      copies: 3,
      hash: "0x2a1ab6e3b5fae89ea53b689e88c9f6560d2b33711e36cc1d4524df6c680271e8",
      exp: 1791634855,
    }),
    '{"p":"nosus-canary","v":1,"t":"seal","note":"0xe5bbe8d0602b1dfda55ea516343e6a5064d021c37e6b7ba648bc5719aea1fc40","copies":3,"hash":"0x2a1ab6e3b5fae89ea53b689e88c9f6560d2b33711e36cc1d4524df6c680271e8","exp":1791634855}',
  );
  // 62Frr29RyPXhhUkAaxDLQHDKinMztPhrsYeokzvoiAAUjp9JBXbNUn3S6D4gX7QEqt2yfurqG54PAERb7fLKCskF
  assertEquals(
    sealMemo({
      note: NOTE_B,
      copies: 10,
      hash: "0x40846d626dd4beb151497162ca5c1de105281a20d076223b76a44ab1d47962df",
      exp: 1791719237,
    }),
    '{"p":"nosus-canary","v":1,"t":"seal","note":"0x56f7956802f494824332309f033188a8850e78b4aed1eca6b1d923534315831d","copies":10,"hash":"0x40846d626dd4beb151497162ca5c1de105281a20d076223b76a44ab1d47962df","exp":1791719237}',
  );
});

Deno.test("openMemo writes the exact devnet open memos", () => {
  // NwoJauec9otkicaGf8yD6UechYgUnXRdYPqnuc5Kpn6uMYym6XVJcMmWdbVnwnRVncKKVgEyuZB2mR3T5REvdSr
  assertEquals(
    openMemo({
      note: NOTE_A,
      copy: 0,
      tag: "0x10947d1df8aaba2c25d2088b054593cfdafd46f959c89007447309960b4845e6",
    }),
    '{"p":"nosus-canary","v":1,"t":"open","note":"0xe5bbe8d0602b1dfda55ea516343e6a5064d021c37e6b7ba648bc5719aea1fc40","copy":0,"tag":"0x10947d1df8aaba2c25d2088b054593cfdafd46f959c89007447309960b4845e6"}',
  );
  // 2b9SS9RhwPvMrsDR5upY5a9w3gk7E2zgV4jmC69QTtZseBMmguXxNdBDqSFTZXW23cgLgAs8L9kFV39LyiU4bnTn
  assertEquals(
    openMemo({
      note: NOTE_B,
      copy: 0,
      tag: "0xe52417df0e5f0b104525ec1a583ec0bb64a71c2358a3e93d855b121172a4d10e",
    }),
    '{"p":"nosus-canary","v":1,"t":"open","note":"0x56f7956802f494824332309f033188a8850e78b4aed1eca6b1d923534315831d","copy":0,"tag":"0xe52417df0e5f0b104525ec1a583ec0bb64a71c2358a3e93d855b121172a4d10e"}',
  );
  // 4NXs89eDP5hm2GyAkuA5rRDBQUNB5e6ssAChQJRCFGTYimyMDa3LmQRbcEVmaezQSXCx8kgt5GRkpUje59WqH2rc
  assertEquals(
    openMemo({
      note: NOTE_B,
      copy: 1,
      tag: "0x6ec7e19683ff70ce1d03ebf3df42242872f98407b47baada27b8cb50d934306e",
    }),
    '{"p":"nosus-canary","v":1,"t":"open","note":"0x56f7956802f494824332309f033188a8850e78b4aed1eca6b1d923534315831d","copy":1,"tag":"0x6ec7e19683ff70ce1d03ebf3df42242872f98407b47baada27b8cb50d934306e"}',
  );
});

Deno.test("memo builders keep their validation messages", () => {
  assertThrows(
    () => sealMemo({ note: "0x12", copies: 2, hash: NOTE_A, exp: 0 }),
    Error,
    "memo note must be 0x + 64 hex chars",
  );
  assertThrows(
    () => openMemo({ note: NOTE_A, copy: -1, tag: NOTE_A }),
    Error,
    "memo copy must be a non-negative integer",
  );
});

Deno.test("the library accepts the same memo programs as @solana-program/memo", () => {
  assertEquals(MEMO_PROGRAM_IDS, [...SUPPORTED_MEMO_PROGRAM_ADDRESSES]);
});

const ENV = ["SOLANA_RELAYER_KEYS", "SOLANA_RPC_URL", "SOLANA_MEMO_PROGRAM"];

function withEnv(env: Record<string, string>, fn: () => void) {
  const saved = ENV.map((k) => [k, Deno.env.get(k)] as const);
  try {
    for (const k of ENV) Deno.env.delete(k);
    for (const [k, v] of Object.entries(env)) Deno.env.set(k, v);
    fn();
  } finally {
    for (const [k, v] of saved) v === undefined ? Deno.env.delete(k) : Deno.env.set(k, v);
  }
}

// Test bytes 1..64 only; not a funded key.
const KEY = JSON.stringify(Array.from({ length: 64 }, (_, i) => i + 1));

Deno.test("loadSolana: defaults, overrides and messages are unchanged", () => {
  withEnv({}, () => assertEquals(loadSolana(), null));
  withEnv({ SOLANA_RELAYER_KEYS: "  " }, () => assertEquals(loadSolana(), null));
  withEnv({ SOLANA_RELAYER_KEYS: KEY }, () => {
    const cfg = loadSolana()!;
    assertEquals(cfg.rpcUrl, "https://api.devnet.solana.com");
    assertEquals(cfg.memoProgram, LEGACY_MEMO_PROGRAM_ADDRESS_V3);
    assertEquals(cfg.keys.length, 1);
  });
  withEnv({
    SOLANA_RELAYER_KEYS: `${KEY},${KEY}`,
    SOLANA_RPC_URL: "http://localhost:8899",
    SOLANA_MEMO_PROGRAM: " Memo4c2pN8afCj432Lb7RMVKi9PbQnnW7ewFFaV3oAH ",
  }, () => {
    const cfg = loadSolana()!;
    assertEquals(cfg.rpcUrl, "http://localhost:8899");
    assertEquals(cfg.memoProgram, "Memo4c2pN8afCj432Lb7RMVKi9PbQnnW7ewFFaV3oAH");
    assertEquals(cfg.keys.length, 2);
  });
  withEnv({ SOLANA_RELAYER_KEYS: KEY, SOLANA_MEMO_PROGRAM: "11111111111111111111111111111111" }, () =>
    assertThrows(loadSolana, Error, "SOLANA_MEMO_PROGRAM is not a known Memo program address"));
  withEnv({ SOLANA_RELAYER_KEYS: "[1,2,3]" }, () =>
    assertThrows(loadSolana, Error, "SOLANA_RELAYER_KEYS: a key must be 64 bytes"));
});
