import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  createPublicClient,
  createWalletClient,
  http,
  keccak256,
  parseAbi,
  stringToHex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

import { buildCanDecryptConditions, LIT_ACC_CHAIN } from "./conditions.mjs";

const spikeRoot = dirname(fileURLToPath(import.meta.url));
const live = process.argv.includes("--live") || process.env.THRESHOLD_SPIKE_RUN === "1";
const connectOnly = process.argv.includes("--connect");
const contractAddress = process.env.DROPS_CONTRACT_ADDRESS;
const dropId = process.env.SPIKE_DROP_ID ?? `0x${"ab".repeat(32)}`;
const senderKey = process.env.SENDER_PRIVATE_KEY;
const recipientKey = process.env.RECIPIENT_PRIVATE_KEY;
const strangerKey = process.env.STRANGER_PRIVATE_KEY;
const rpcUrl = process.env.MONAD_RPC_URL ?? "https://rpc.testnet.monad.xyz";
const expirySeconds = BigInt(process.env.SPIKE_EXPIRY_SECONDS ?? "300");
const checkExpiry = process.env.THRESHOLD_SPIKE_CHECK_EXPIRY === "1";
const probe = "gate-t1-probe";

const monadTestnet = {
  id: 10143,
  name: "Monad Testnet",
  nativeCurrency: { name: "MON", symbol: "MON", decimals: 18 },
  rpcUrls: { default: { http: [rpcUrl] } },
};

const dropsAbi = parseAbi([
  "function seal(bytes32 id, bytes32 ciphertextDigest, address recipient, uint64 expiresAt)",
  "function acknowledgeOpen(bytes32 id)",
  "function canDecrypt(bytes32 id, address account) view returns (bool)",
]);

const missing = [];
if (!contractAddress) missing.push("DROPS_CONTRACT_ADDRESS");
if (!senderKey) missing.push("SENDER_PRIVATE_KEY");
if (!recipientKey) missing.push("RECIPIENT_PRIVATE_KEY");
if (!strangerKey) missing.push("STRANGER_PRIVATE_KEY");

const conditionContract = contractAddress ?? "0x0000000000000000000000000000000000000001";
const conditions = buildCanDecryptConditions(conditionContract, dropId);

console.log("NO SUS — Monad Experiment / Gate T1");
console.log("Lit ACC chain:", LIT_ACC_CHAIN);
console.log("Selected SDK: @lit-protocol/lit-client 8.3.1, @lit-protocol/networks 8.4.1, @lit-protocol/auth 8.2.3 on naga-dev");
console.log("Condition:");
console.log(JSON.stringify(conditions, null, 2));

if (!live && !connectOnly) {
  console.log("\nDry run only. This does not connect to Lit or Monad and does not enable the product gate.");
  console.log("Use --connect for a Lit handshake. The full proof requires THRESHOLD_SPIKE_RUN=1, a deployed contract, and three controlled test wallets.");
  process.exit(0);
}

if (!existsSync(join(spikeRoot, "node_modules", "@lit-protocol", "lit-client"))) {
  console.error("Lit client is not installed. Run npm install in tool/threshold-spike.");
  process.exit(1);
}

const [{ createLitClient }, networks, auth] = await Promise.all([
  import("@lit-protocol/lit-client"),
  import("@lit-protocol/networks"),
  import("@lit-protocol/auth"),
]);

const network = networks.nagaDev ?? networks.nagaTest;
if (!network) {
  console.error("The installed @lit-protocol/networks package does not export nagaDev or nagaTest.");
  process.exit(1);
}

const client = await createLitClient({ network });
console.log("Connected to Lit naga-dev.");

let encrypted;
try {
  encrypted = await client.encrypt({
    dataToEncrypt: new TextEncoder().encode(probe),
    evmContractConditions: conditions,
    chain: LIT_ACC_CHAIN,
  });
  console.log("Lit encrypt accepted the Monad canDecrypt condition.");
  console.log("Returned fields:", Object.keys(encrypted));
} catch (error) {
  console.error("Lit encrypt against monadTestnet failed. Record this as Gate T1 evidence, not a product claim.");
  console.error(error instanceof Error ? error.message : error);
  await client.disconnect?.();
  process.exit(1);
}

if (connectOnly && !live) {
  await client.disconnect?.();
  console.log("Handshake and encrypt-only completed. Product gate remains spike-required.");
  process.exit(0);
}

if (missing.length) {
  await client.disconnect?.();
  console.error(`Live proof refused. Missing ${missing.join(", ")}.`);
  process.exit(1);
}

const sender = privateKeyToAccount(senderKey);
const recipient = privateKeyToAccount(recipientKey);
const stranger = privateKeyToAccount(strangerKey);
const publicClient = createPublicClient({ chain: monadTestnet, transport: http(rpcUrl) });
const senderClient = createWalletClient({ account: sender, chain: monadTestnet, transport: http(rpcUrl) });
const recipientClient = createWalletClient({ account: recipient, chain: monadTestnet, transport: http(rpcUrl) });

const code = await publicClient.getCode({ address: contractAddress });
if (!code || code === "0x") {
  await client.disconnect?.();
  console.error("Live proof refused: DROPS_CONTRACT_ADDRESS has no deployed bytecode on the configured Monad RPC.");
  process.exit(1);
}

const authManager = auth.createAuthManager({
  storage: auth.storagePlugins.localStorageNode({
    appName: "nosus-monad-threshold-spike",
    networkName: "naga-dev",
    storagePath: join(spikeRoot, ".lit-auth"),
  }),
});

async function authContextFor(account) {
  return authManager.createEoaAuthContext({
    config: { account },
    litClient: client,
    authConfig: {
      domain: "localhost",
      statement: "NO SUS Monad Gate T1 two-wallet test",
    },
  });
}

async function decryptAs(account) {
  return client.decrypt({
    data: encrypted,
    evmContractConditions: conditions,
    chain: LIT_ACC_CHAIN,
    authContext: await authContextFor(account),
  });
}

async function expectDenied(label, account) {
  try {
    await decryptAs(account);
  } catch {
    console.log(`PASS: ${label} was denied.`);
    return;
  }
  throw new Error(`${label} unexpectedly decrypted the probe.`);
}

async function waitForSuccess(hash) {
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error(`Transaction reverted: ${hash}`);
  return receipt;
}

async function waitUntilExpired(expiresAt) {
  while ((await publicClient.getBlock()).timestamp < expiresAt) {
    await new Promise((resolve) => setTimeout(resolve, 5_000));
  }
}

try {
  const existing = await publicClient.readContract({
    address: contractAddress,
    abi: dropsAbi,
    functionName: "canDecrypt",
    args: [dropId, recipient.address],
  });
  if (existing) throw new Error("SPIKE_DROP_ID already grants access. Use a fresh random 32-byte drop ID.");

  await expectDenied("recipient before acknowledgement", recipient);

  const ciphertextDigest = keccak256(stringToHex(encrypted.ciphertext));
  const now = (await publicClient.getBlock()).timestamp;
  const sealHash = await senderClient.writeContract({
    address: contractAddress,
    abi: dropsAbi,
    functionName: "seal",
    args: [dropId, ciphertextDigest, recipient.address, now + expirySeconds],
    gas: 190_000n,
  });
  await waitForSuccess(sealHash);
  console.log("PASS: sender sealed the ciphertext digest.");

  const acknowledgeHash = await recipientClient.writeContract({
    address: contractAddress,
    abi: dropsAbi,
    functionName: "acknowledgeOpen",
    args: [dropId],
    gas: 100_000n,
  });
  await waitForSuccess(acknowledgeHash);
  console.log("PASS: named recipient acknowledged the drop.");

  const recipientResult = await decryptAs(recipient);
  const recovered = new TextDecoder().decode(recipientResult.decryptedData);
  if (recovered !== probe) throw new Error("Recipient decrypt returned unexpected bytes.");
  console.log("PASS: acknowledged recipient decrypted the probe.");

  await expectDenied("stranger after acknowledgement", stranger);

  if (checkExpiry) {
    console.log("Waiting for the configured expiry before the final denial check.");
    await waitUntilExpired(now + expirySeconds);
    await expectDenied("recipient after expiry", recipient);
  } else {
    console.log("Expiry denial is not included. Re-run with THRESHOLD_SPIKE_CHECK_EXPIRY=1 to record it.");
  }

  console.log("Gate T1 live proof completed. Record transaction hashes and results in docs/STATUS.md before changing the product gate.");
} catch (error) {
  console.error("Gate T1 live proof failed. Product gate remains spike-required.");
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
} finally {
  await client.disconnect?.();
}
