import { network } from "hardhat";

if (process.env.CONFIRM_MONAD_DEPLOY !== "1") {
  throw new Error(
    "Refusing to deploy to Monad Testnet. After an explicit named-target approval, set CONFIRM_MONAD_DEPLOY=1.",
  );
}

const connection = await network.create("monadTestnet");
const { viem } = connection;
const canary = await viem.deployContract("NoSusCanary");

console.log(`NoSusCanary deployed at: ${canary.address}`);
console.log("Next: set CANARY_CONTRACT_ADDRESS to this value and run scripts/canary-relayers.ts.");
