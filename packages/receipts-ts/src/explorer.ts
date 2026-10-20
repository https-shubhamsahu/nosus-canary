export type Cluster = "devnet" | "mainnet-beta";

/** Default public RPC endpoint for each cluster. */
export const DEFAULT_RPC_URLS: Readonly<Record<Cluster, string>> = Object.freeze({
  "devnet": "https://api.devnet.solana.com",
  "mainnet-beta": "https://api.mainnet-beta.solana.com",
});

/** Solana Explorer page for a transaction. Mainnet takes no cluster param. */
export function explorerTxUrl(signature: string, cluster: Cluster = "devnet"): string {
  const base = `https://explorer.solana.com/tx/${signature}`;
  return cluster === "mainnet-beta" ? base : `${base}?cluster=${cluster}`;
}
