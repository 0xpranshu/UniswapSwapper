import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
import "@openzeppelin/hardhat-upgrades";

dotenv.config();

const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY;
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL;
const SEPOLIA_ETHERSCAN_API_KEY = process.env.SEPOLIA_ETHERSCAN_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  external: {
    contracts: [
      {
        artifacts: "node_modules/@openzeppelin/contracts-upgradeable/build/contracts",
      },
    ],
  },
  networks: {
    sepolia: {
      url: SEPOLIA_RPC_URL || "https://ethereum-sepolia.blockpi.network/v1/rpc/public",
      accounts: DEPLOYER_PRIVATE_KEY ? [`0x${DEPLOYER_PRIVATE_KEY}`] : [],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: SEPOLIA_ETHERSCAN_API_KEY,
    }
  }
};
