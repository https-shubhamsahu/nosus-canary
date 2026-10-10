// Which proof chains a canary request writes to. Pure functions only (no env,
// no network) so the rules can be checked with `deno test` offline.
//
// Solana devnet is the product's receipt. Monad testnet is the earlier
// prototype and is on only while CANARY_CONTRACT_ADDRESS is set.

/** Monad is on only when a contract address is configured (blank = off). */
export function monadEnabled(contractAddress: string | null | undefined): boolean {
  return (contractAddress ?? "").trim() !== "";
}

type SealFields = { seal_tx_hash?: string | null; seal_solana_sig?: string | null };

/** A note is sealed once either chain holds its seal. */
export function isSealed(note: SealFields | null | undefined): boolean {
  return !!note && (!!note.seal_tx_hash || !!note.seal_solana_sig);
}

export type SealPlan = {
  /** Send sealNote on Monad (in parallel with Solana, Monad authoritative). */
  monad: boolean;
  /** Send the seal memo on Solana. */
  solana: boolean;
  /** A failed Solana memo must fail the request (Solana is the only receipt). */
  solanaRequired: boolean;
};

export function planSeal(p: {
  monadOn: boolean;
  solanaOn: boolean;
  sealTx: string | null;
  sealSolana: string | null;
}): SealPlan {
  const sealed = isSealed({ seal_tx_hash: p.sealTx, seal_solana_sig: p.sealSolana });
  const solana = p.solanaOn && !p.sealSolana;
  return {
    monad: p.monadOn && !p.sealTx,
    solana,
    solanaRequired: solana && !p.monadOn && !sealed,
  };
}

export type OpenPlan = {
  /** Send openCopy on Monad (only for notes sealed there). */
  monad: boolean;
  /** Send the open memo on Solana. A failure is stored as null and retried. */
  solana: boolean;
};

export function planOpen(p: {
  monadOn: boolean;
  solanaOn: boolean;
  noteSealTx: string | null;
  openTx: string | null;
  openSolana: string | null;
}): OpenPlan {
  return {
    monad: p.monadOn && !!p.noteSealTx && !p.openTx,
    solana: p.solanaOn && !p.openSolana,
  };
}
