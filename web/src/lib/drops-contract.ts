import { createPublicClient, http, type Address, type Hex } from "viem";

import { publicEnvironment } from "@/lib/env";
import {
  monadTestnet,
  noSusMonadDropsAbi,
  type DropReceipt,
} from "@/lib/monad";
import { connectInjectedWallet } from "@/lib/wallet";

function contractAddress(): Address {
  const address = publicEnvironment.dropsContractAddress;
  if (!address) throw new Error("The Monad drops contract has not been configured.");
  return address;
}

function publicClient() {
  return createPublicClient({
    chain: monadTestnet,
    transport: http(publicEnvironment.monadRpcUrl),
  });
}

function paddedGas(estimatedGas: bigint): bigint {
  return (estimatedGas * 120n) / 100n;
}

async function waitForSuccessfulReceipt(hash: Hex) {
  const receipt = await publicClient().waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") {
    throw new Error(`Monad transaction reverted: ${hash}`);
  }
  return receipt;
}

export async function sealDrop(args: {
  dropId: Hex;
  ciphertextDigest: Hex;
  recipient: Address;
  expiresAt: bigint;
}): Promise<{ hash: Hex; address: Address }> {
  const { address, client: walletClient } = await connectInjectedWallet();
  const request = {
    account: address,
    address: contractAddress(),
    abi: noSusMonadDropsAbi,
    functionName: "seal" as const,
    args: [args.dropId, args.ciphertextDigest, args.recipient, args.expiresAt] as const,
  };
  const hash = await walletClient.writeContract({
    ...request,
    gas: paddedGas(await publicClient().estimateContractGas(request)),
  });
  await waitForSuccessfulReceipt(hash);
  return { hash, address };
}

export async function acknowledgeOpen(dropId: Hex): Promise<{ hash: Hex; address: Address }> {
  const { address, client: walletClient } = await connectInjectedWallet();
  const request = {
    account: address,
    address: contractAddress(),
    abi: noSusMonadDropsAbi,
    functionName: "acknowledgeOpen" as const,
    args: [dropId] as const,
  };
  const hash = await walletClient.writeContract({
    ...request,
    gas: paddedGas(await publicClient().estimateContractGas(request)),
  });
  await waitForSuccessfulReceipt(hash);
  return { hash, address };
}

export async function receiptOf(dropId: Hex): Promise<DropReceipt> {
  return (await publicClient().readContract({
    address: contractAddress(),
    abi: noSusMonadDropsAbi,
    functionName: "receiptOf",
    args: [dropId],
  })) as DropReceipt;
}

export async function canDecrypt(dropId: Hex, account: Address): Promise<boolean> {
  return (await publicClient().readContract({
    address: contractAddress(),
    abi: noSusMonadDropsAbi,
    functionName: "canDecrypt",
    args: [dropId, account],
  })) as boolean;
}
