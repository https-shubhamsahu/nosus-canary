import {
  createWalletClient,
  custom,
  getAddress,
} from "viem";

import { monadTestnet } from "@/lib/monad";

const monadChainHex = `0x${monadTestnet.id.toString(16)}`;

export async function connectInjectedWallet() {
  const provider = window.ethereum;
  if (!provider) {
    throw new Error("No injected wallet was found. Install or open a testnet wallet first.");
  }

  const accounts = (await provider.request({
    method: "eth_requestAccounts",
  })) as string[];
  const account = accounts[0];
  if (!account) throw new Error("The wallet did not return an account.");

  const activeChain = (await provider.request({ method: "eth_chainId" })) as string;
  if (activeChain.toLowerCase() !== monadChainHex) {
    try {
      await provider.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: monadChainHex }],
      });
    } catch (error) {
      const code = (error as { code?: number }).code;
      if (code !== 4902) throw error;
      await provider.request({
        method: "wallet_addEthereumChain",
        params: [
          {
            chainId: monadChainHex,
            chainName: monadTestnet.name,
            nativeCurrency: monadTestnet.nativeCurrency,
            rpcUrls: monadTestnet.rpcUrls.default.http,
            blockExplorerUrls: [monadTestnet.blockExplorers.default.url],
          },
        ],
      });
    }
  }

  const address = getAddress(account);
  return {
    address,
    client: createWalletClient({
      account: address,
      chain: monadTestnet,
      transport: custom(provider),
    }),
  };
}
