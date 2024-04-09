import { ethers, upgrades } from "hardhat";

const WETH = "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9";
const UNISWAP_V2_FACTORY = "0x7E0987E5b3a30e3f2828572Bb659A548460a3003";

async function main() {
  const erc20SwapperFactory = await ethers.getContractFactory("ERC20Swapper");

  console.log("ERC20Swapper is deploying........");
  const erc20Swapper = await upgrades.deployProxy(erc20SwapperFactory, [UNISWAP_V2_FACTORY], {
    constructorArgs: [WETH],
    initializer: "initialize(address)",
  });
  console.log("ERC20Swapper deployed at address: ", await erc20Swapper.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
