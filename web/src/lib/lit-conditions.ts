import type { Address, Hex } from "viem";

import { canDecryptFunctionAbi } from "@/lib/monad";

/**
 * Lit's published EVM chain map includes this key for Monad Testnet (chain ID
 * 10143). That is the identifier to send in `evmContractConditions`. It is not
 * proof that Lit nodes currently evaluate it; Gate T1 still has to record a
 * live decrypt result.
 *
 * Source: ACC schema enum in @lit-protocol/accs-schemas (includes monadTestnet)
 */
export const LIT_ACC_CHAIN = "monadTestnet" as const;

export type CanDecryptCondition = {
  contractAddress: Address;
  chain: typeof LIT_ACC_CHAIN;
  functionName: "canDecrypt";
  functionParams: [Hex, ":userAddress"];
  functionAbi: typeof canDecryptFunctionAbi;
  returnValueTest: {
    key: "";
    comparator: "=";
    value: "true";
  };
};

export function buildCanDecryptConditions(
  contractAddress: Address,
  dropId: Hex,
): CanDecryptCondition[] {
  return [
    {
      contractAddress,
      chain: LIT_ACC_CHAIN,
      functionName: "canDecrypt",
      functionParams: [dropId, ":userAddress"],
      functionAbi: canDecryptFunctionAbi,
      returnValueTest: {
        key: "",
        comparator: "=",
        value: "true",
      },
    },
  ];
}
