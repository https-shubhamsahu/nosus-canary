/**
 * Canonical Lit access-control condition for Gate T1.
 * Keep this aligned with web/src/lib/lit-conditions.ts.
 */

export const LIT_ACC_CHAIN = "monadTestnet";
export const CAN_DECRYPT_ABI = {
  name: "canDecrypt",
  type: "function",
  stateMutability: "view",
  inputs: [
    { name: "id", type: "bytes32" },
    { name: "account", type: "address" },
  ],
  outputs: [{ name: "", type: "bool", internalType: "bool" }],
};

export function buildCanDecryptConditions(contractAddress, dropId) {
  return [
    {
      contractAddress,
      chain: LIT_ACC_CHAIN,
      functionName: "canDecrypt",
      functionParams: [dropId, ":userAddress"],
      functionAbi: CAN_DECRYPT_ABI,
      returnValueTest: {
        key: "",
        comparator: "=",
        value: "true",
      },
    },
  ];
}
