import { defineChain, type Address } from "viem";

export const monadTestnet = defineChain({
  id: 10143,
  name: "Monad Testnet",
  nativeCurrency: { name: "MON", symbol: "MON", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://rpc.testnet.monad.xyz"] },
  },
  blockExplorers: {
    default: { name: "Monadscan", url: "https://testnet.monadscan.com" },
  },
  testnet: true,
});

export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as const;

export const canDecryptFunctionAbi = {
  name: "canDecrypt",
  type: "function",
  stateMutability: "view",
  inputs: [
    { name: "id", type: "bytes32" },
    { name: "account", type: "address" },
  ],
  outputs: [{ name: "", type: "bool", internalType: "bool" }],
} as const;

export const noSusMonadDropsAbi = [
  {
    type: "function",
    name: "seal",
    stateMutability: "nonpayable",
    inputs: [
      { name: "id", type: "bytes32" },
      { name: "ciphertextDigest", type: "bytes32" },
      { name: "recipient", type: "address" },
      { name: "expiresAt", type: "uint64" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "acknowledgeOpen",
    stateMutability: "nonpayable",
    inputs: [{ name: "id", type: "bytes32" }],
    outputs: [],
  },
  {
    ...canDecryptFunctionAbi,
  },
  {
    type: "function",
    name: "receiptOf",
    stateMutability: "view",
    inputs: [{ name: "id", type: "bytes32" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "sender", type: "address" },
          { name: "recipient", type: "address" },
          { name: "opener", type: "address" },
          { name: "ciphertextDigest", type: "bytes32" },
          { name: "sealedAt", type: "uint64" },
          { name: "openedAt", type: "uint64" },
          { name: "expiresAt", type: "uint64" },
        ],
      },
    ],
  },
  {
    type: "event",
    name: "Sealed",
    inputs: [
      { name: "id", type: "bytes32", indexed: true },
      { name: "sender", type: "address", indexed: true },
      { name: "recipient", type: "address", indexed: true },
      { name: "ciphertextDigest", type: "bytes32", indexed: false },
      { name: "expiresAt", type: "uint64", indexed: false },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OpenAcknowledged",
    inputs: [
      { name: "id", type: "bytes32", indexed: true },
      { name: "opener", type: "address", indexed: true },
      { name: "openedAt", type: "uint64", indexed: false },
    ],
    anonymous: false,
  },
] as const;

export type DropReceipt = {
  sender: Address;
  recipient: Address;
  opener: Address;
  ciphertextDigest: `0x${string}`;
  sealedAt: bigint;
  openedAt: bigint;
  expiresAt: bigint;
};
