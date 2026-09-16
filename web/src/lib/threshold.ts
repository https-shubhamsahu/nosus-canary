import { buildCanDecryptConditions, LIT_ACC_CHAIN } from "@/lib/lit-conditions";

/**
 * This module is the safety latch for the product's only novel promise.
 *
 * Lit supports client-side encryption and access-control conditions, and Lit's
 * ACC schema includes chain key `monadTestnet`. The exact
 * `canDecrypt(dropId, wallet)` condition has not yet been proven against two
 * wallets on Monad Testnet. The application remains non-operational until that
 * evidence is documented in docs/STATUS.md.
 */
export const thresholdGate = {
  status: "spike-required" as const,
  accChain: LIT_ACC_CHAIN,
  litSdk: {
    client: "@lit-protocol/lit-client",
    networks: "@lit-protocol/networks",
    auth: "@lit-protocol/auth",
    versions: {
      client: "8.3.1",
      networks: "8.4.1",
      auth: "8.2.3",
    },
    network: "naga-dev",
    source: "https://www.npmjs.com/package/@lit-protocol/lit-client",
  },
  requiredEvidence: [
    "Before acknowledgeOpen, recipient wallet A fails Lit decryption.",
    "Wallet A acknowledges and can decrypt.",
    "Wallet B fails Lit decryption for the same ciphertext.",
    "A second acknowledgeOpen reverts and does not change the opener.",
    "After expiry, no wallet can decrypt.",
    "Tampered ciphertext fails; no plaintext is logged.",
  ],
};

export { buildCanDecryptConditions, LIT_ACC_CHAIN };

export function assertThresholdGateVerified(): never {
  throw new Error(
    "Threshold decrypt is disabled until the Lit–Monad two-wallet testnet gate is verified.",
  );
}
