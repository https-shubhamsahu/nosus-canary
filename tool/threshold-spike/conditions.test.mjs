import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { buildCanDecryptConditions, LIT_ACC_CHAIN } from "./conditions.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const webSource = readFileSync(join(root, "web/src/lib/lit-conditions.ts"), "utf8");

test("the condition binds canDecrypt to the authenticated wallet on monadTestnet", () => {
  const dropId = `0x${"11".repeat(32)}`;
  const contract = "0x0000000000000000000000000000000000000001";
  const [condition] = buildCanDecryptConditions(contract, dropId);

  assert.equal(LIT_ACC_CHAIN, "monadTestnet");
  assert.equal(condition.chain, "monadTestnet");
  assert.equal(condition.functionName, "canDecrypt");
  assert.deepEqual(condition.functionParams, [dropId, ":userAddress"]);
  assert.equal(condition.returnValueTest.value, "true");
  const serialized = JSON.stringify(condition);
  assert.doesNotMatch(serialized, /plaintext|privateKey|salt/i);
  assert.equal(condition.functionParams.includes(":userAddress"), true);
});

test("the web module uses the same chain, predicate, and user-address binding", () => {
  assert.match(webSource, /export const LIT_ACC_CHAIN = "monadTestnet"/);
  assert.match(webSource, /functionName: "canDecrypt"/);
  assert.match(webSource, /:userAddress/);
  assert.match(webSource, /value: "true"/);
});
