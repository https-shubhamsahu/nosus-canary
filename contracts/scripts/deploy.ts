import { network } from "hardhat";

if (process.env.CONFIRM_MONAD_DEPLOY !== "1") {
  throw new Error(
    "Refusing to deploy to Monad Testnet. After an explicit named-target approval, set CONFIRM_MONAD_DEPLOY=1.",
  );
}

const connection = await network.create("monadTestnet");
const { viem } = connection;
const drops = await viem.deployContract("NoSusMonadDrops");

console.log(`NoSusMonadDrops deployed at: ${drops.address}`);
console.log("Record this address in web/.env.local as NEXT_PUBLIC_DROPS_CONTRACT_ADDRESS.");
