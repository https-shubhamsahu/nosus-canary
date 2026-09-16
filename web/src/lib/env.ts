import { isAddress, type Address } from "viem";

function configuredAddress(value: string | undefined): Address | undefined {
  return value && isAddress(value) ? value : undefined;
}

export const publicEnvironment = {
  monadRpcUrl:
    process.env.NEXT_PUBLIC_MONAD_RPC_URL ?? "https://rpc.testnet.monad.xyz",
  monadExplorerUrl:
    process.env.NEXT_PUBLIC_MONAD_EXPLORER_URL ?? "https://testnet.monadscan.com",
  dropsContractAddress: configuredAddress(
    process.env.NEXT_PUBLIC_DROPS_CONTRACT_ADDRESS,
  ),
  supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL,
  supabasePublishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
};

export function missingRuntimeConfiguration(): string[] {
  const missing: string[] = [];
  if (!publicEnvironment.dropsContractAddress) missing.push("drops contract");
  if (!publicEnvironment.supabaseUrl || !publicEnvironment.supabasePublishableKey) {
    missing.push("isolated Supabase project");
  }
  return missing;
}
