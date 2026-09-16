import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { buildCanDecryptConditions, LIT_ACC_CHAIN } from "./conditions.mjs";

const spikeRoot = dirname(fileURLToPath(import.meta.url));
const live = process.argv.includes("--live") || process.env.THRESHOLD_SPIKE_RUN === "1";
const connectOnly = process.argv.includes("--connect");

const contractAddress = process.env.DROPS_CONTRACT_ADDRESS;
const dropId = process.env.SPIKE_DROP_ID ?? `0x${"ab".repeat(32)}`;
const recipientKey = process.env.RECIPIENT_PRIVATE_KEY;
const strangerKey = process.env.STRANGER_PRIVATE_KEY;

const missing = [];
if (!contractAddress) missing.push("DROPS_CONTRACT_ADDRESS");
if (!recipientKey) missing.push("RECIPIENT_PRIVATE_KEY");
if (!strangerKey) missing.push("STRANGER_PRIVATE_KEY");

const conditions = contractAddress
  ? buildCanDecryptConditions(contractAddress, dropId)
  : buildCanDecryptConditions("0x0000000000000000000000000000000000000001", dropId);

console.log("NO SUS — Monad Experiment / Gate T1");
console.log("Lit ACC chain:", LIT_ACC_CHAIN);
console.log("Selected SDK: @lit-protocol/lit-client 8.3.1, @lit-protocol/networks 8.4.1, @lit-protocol/auth 8.2.3 on naga-dev");
console.log("Condition:");
console.log(JSON.stringify(conditions, null, 2));

if (!live && !connectOnly) {
  console.log("\nDry run only. This does not connect to Lit or Monad and does not enable the product gate.");
  console.log("Use --connect to handshake naga-dev. Live two-wallet proof requires THRESHOLD_SPIKE_RUN=1 plus a deployed contract and two test wallets.");
  process.exit(0);
}

if (!existsSync(join(spikeRoot, "node_modules", "@lit-protocol", "lit-client"))) {
  console.error("Lit client is not installed. Run npm install in tool/threshold-spike.");
  process.exit(1);
}

const [{ createLitClient }, networks] = await Promise.all([
  import("@lit-protocol/lit-client"),
  import("@lit-protocol/networks"),
]);

const network = networks.nagaDev ?? networks.nagaTest;
if (!network) {
  console.error("The installed @lit-protocol/networks package does not export nagaDev or nagaTest.");
  process.exit(1);
}

const client = await createLitClient({ network });
console.log("Connected to Lit naga-dev.");

const dataToEncrypt = new TextEncoder().encode("gate-t1-probe");
try {
  const encrypted = await client.encrypt({
    dataToEncrypt,
    evmContractConditions: conditions,
    chain: LIT_ACC_CHAIN,
  });
  console.log("Lit encrypt accepted the monadTestnet canDecrypt condition.");
  console.log("Returned fields:", Object.keys(encrypted));
} catch (error) {
  console.error("Lit encrypt against monadTestnet failed. Record this as Gate T1 evidence, not a product claim.");
  console.error(error instanceof Error ? error.message : error);
  await client.disconnect?.();
  process.exit(1);
}

if (connectOnly && !live) {
  await client.disconnect?.();
  console.log("Handshake and encrypt-only. Decrypt still needs two wallets and a deployed contract. Product gate remains spike-required.");
  process.exit(0);
}

if (missing.length) {
  await client.disconnect?.();
  console.error(`Live decrypt refused. Missing ${missing.join(", ")}.`);
  process.exit(1);
}

await client.disconnect?.();
console.log("Wallet decrypt is not wired in this runner yet. Record encrypt/handshake results in STATUS.md; do not flip the product gate.");
