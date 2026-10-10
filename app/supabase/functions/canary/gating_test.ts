// Offline checks for the proof-chain rules. Run from the repo root:
//   npx -y deno@2 test app/supabase/functions/canary/gating_test.ts
import { assertEquals } from "jsr:@std/assert@1";
import { isSealed, monadEnabled, planOpen, planSeal } from "./gating.ts";

const TX = "0x" + "a".repeat(64);
const SIG = "5".repeat(88);

Deno.test("monadEnabled: only a non-blank contract address turns Monad on", () => {
  assertEquals(monadEnabled(undefined), false);
  assertEquals(monadEnabled(null), false);
  assertEquals(monadEnabled(""), false);
  assertEquals(monadEnabled("   "), false);
  assertEquals(monadEnabled("0x" + "1".repeat(40)), true);
});

Deno.test("isSealed: either chain's seal counts", () => {
  assertEquals(isSealed(null), false);
  assertEquals(isSealed({ seal_tx_hash: null, seal_solana_sig: null }), false);
  assertEquals(isSealed({ seal_tx_hash: TX, seal_solana_sig: null }), true);
  assertEquals(isSealed({ seal_tx_hash: null, seal_solana_sig: SIG }), true);
});

Deno.test("planSeal: Solana only, new note -> Solana required", () => {
  assertEquals(
    planSeal({ monadOn: false, solanaOn: true, sealTx: null, sealSolana: null }),
    { monad: false, solana: true, solanaRequired: true },
  );
});

Deno.test("planSeal: Solana only, already sealed -> nothing to send", () => {
  assertEquals(
    planSeal({ monadOn: false, solanaOn: true, sealTx: null, sealSolana: SIG }),
    { monad: false, solana: false, solanaRequired: false },
  );
  // Sealed on Monad by an older build: fill the memo quietly.
  assertEquals(
    planSeal({ monadOn: false, solanaOn: true, sealTx: TX, sealSolana: null }),
    { monad: false, solana: true, solanaRequired: false },
  );
});

Deno.test("planSeal: both on behaves as before (Monad authoritative)", () => {
  assertEquals(
    planSeal({ monadOn: true, solanaOn: true, sealTx: null, sealSolana: null }),
    { monad: true, solana: true, solanaRequired: false },
  );
  assertEquals(
    planSeal({ monadOn: true, solanaOn: true, sealTx: TX, sealSolana: null }),
    { monad: false, solana: true, solanaRequired: false },
  );
  assertEquals(
    planSeal({ monadOn: true, solanaOn: false, sealTx: null, sealSolana: null }),
    { monad: true, solana: false, solanaRequired: false },
  );
});

Deno.test("planOpen: Solana only never touches Monad", () => {
  assertEquals(
    planOpen({ monadOn: false, solanaOn: true, noteSealTx: TX, openTx: null, openSolana: null }),
    { monad: false, solana: true },
  );
  assertEquals(
    planOpen({ monadOn: false, solanaOn: true, noteSealTx: null, openTx: null, openSolana: SIG }),
    { monad: false, solana: false },
  );
});

Deno.test("planOpen: both on behaves as before", () => {
  assertEquals(
    planOpen({ monadOn: true, solanaOn: true, noteSealTx: TX, openTx: null, openSolana: null }),
    { monad: true, solana: true },
  );
  assertEquals(
    planOpen({ monadOn: true, solanaOn: true, noteSealTx: TX, openTx: TX, openSolana: null }),
    { monad: false, solana: true },
  );
  // A note sealed only on Solana is never opened on Monad (the contract would revert).
  assertEquals(
    planOpen({ monadOn: true, solanaOn: true, noteSealTx: null, openTx: null, openSolana: null }),
    { monad: false, solana: true },
  );
});
