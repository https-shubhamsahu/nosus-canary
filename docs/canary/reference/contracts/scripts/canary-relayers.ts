// Creates (once) and funds the relayer keys the `canary` edge function uses,
// and allow-lists them on NoSusCanary. Safe to re-run: it reuses the saved
// keys, only tops up balances below half the target, and skips relayers that
// are already allowed.
//
// Keys are written to contracts/.canary-relayers.local.json (git-ignored).
// They are TESTNET-ONLY keys. Never print them, commit them or reuse them.
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { network } from "hardhat";
import { parseEther } from "viem";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";

if (process.env.CONFIRM_MONAD_DEPLOY !== "1") {
  throw new Error("Refusing to touch Monad Testnet without CONFIRM_MONAD_DEPLOY=1.");
}
const contract = process.env.CANARY_CONTRACT_ADDRESS;
if (!contract || !/^0x[0-9a-fA-F]{40}$/.test(contract)) {
  throw new Error("Set CANARY_CONTRACT_ADDRESS to the deployed NoSusCanary address.");
}
const count = Number(process.env.CANARY_RELAYER_COUNT ?? "6");
const fundEach = parseEther(process.env.CANARY_RELAYER_FUND_MON ?? "1");
const file = ".canary-relayers.local.json";

const keys: `0x${string}`[] = existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : [];
while (keys.length < count) keys.push(generatePrivateKey());
writeFileSync(file, JSON.stringify(keys, null, 2));

const { viem } = await network.create("monadTestnet");
const [owner] = await viem.getWalletClients();
const publicClient = await viem.getPublicClient();
const canary = await viem.getContractAt("NoSusCanary", contract as `0x${string}`);

for (const key of keys) {
  const relayer = privateKeyToAccount(key).address;
  const balance = await publicClient.getBalance({ address: relayer });
  if (balance < fundEach / 2n) {
    const hash = await owner.sendTransaction({ to: relayer, value: fundEach });
    await publicClient.waitForTransactionReceipt({ hash });
  }
  if (!(await canary.read.isRelayer([relayer]))) {
    const hash = await canary.write.setRelayer([relayer, true]);
    await publicClient.waitForTransactionReceipt({ hash });
  }
  console.log(`relayer ready: ${relayer}`);
}
console.log(`${keys.length} relayers ready. Keys saved in contracts/${file} (git-ignored).`);
