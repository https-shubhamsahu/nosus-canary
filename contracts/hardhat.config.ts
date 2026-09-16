import type { HardhatUserConfig } from "hardhat/config";
import hardhatToolboxViem from "@nomicfoundation/hardhat-toolbox-viem";

const monadRpcUrl = process.env.MONAD_RPC_URL ?? "https://rpc.testnet.monad.xyz";
const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY;

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViem],
  solidity: {
    version: "0.8.24",
  },
  networks: {
    monadTestnet: {
      type: "http",
      chainType: "generic",
      url: monadRpcUrl,
      chainId: 10143,
      accounts: deployerPrivateKey ? [deployerPrivateKey] : [],
    },
  },
};

export default config;
