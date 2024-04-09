import { expect } from "chai";
import { Contract, parseUnits } from "ethers";
import { ethers, upgrades } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { setForkBlock } from "./utils";

const WETH = "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9";
const USDT = "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0";
const DTT = "0xaC17ed19C0Db958ee65e72bE2061d976c63b50FE"; // deflationary token
const UNISWAP_V2_FACTORY = "0x7E0987E5b3a30e3f2828572Bb659A548460a3003";
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

describe("ERC20Swapper", () => {
    let erc20Swapper: Contract;
    let usdt: Contract;
    let dtt: Contract;
    let user: SignerWithAddress

    before(async () => {
        await setForkBlock(5660851);
        [user,] = await ethers.getSigners();
    });

    beforeEach(async () => {
        const erc20SwapperFactory = await ethers.getContractFactory("ERC20Swapper");
        erc20Swapper = await upgrades.deployProxy(erc20SwapperFactory, [UNISWAP_V2_FACTORY], {
            constructorArgs: [WETH],
            initializer: "initialize(address)",
        });

        usdt = await ethers.getContractAt("ERC20", USDT);
        dtt = await ethers.getContractAt("ERC20", DTT);
    });

    describe("setFactoryAddress", () => {
        it("should revert when zero address is passed", async () => {
            await expect(erc20Swapper.setFactoryAddress(ZERO_ADDRESS)).to.be.revertedWithCustomError(erc20Swapper, "ZeroAddressNotAllowed");
        });

        it("should revert when non-owner is calling the function", async () => {
            const [, user2] = await ethers.getSigners();
            await expect(erc20Swapper.connect(user2).setFactoryAddress(UNISWAP_V2_FACTORY)).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("should emit event on success", async () => {
            expect(await erc20Swapper.setFactoryAddress(UNISWAP_V2_FACTORY)).to.emit(erc20Swapper, "FactoryAddressUpdated");
        });
    });

    describe("swapEtherToToken", () => {
        it("Should revert when zero address is provided", async () => {
            await expect(erc20Swapper.swapEtherToToken(ZERO_ADDRESS, 0)).to.be.revertedWithCustomError(erc20Swapper, "ZeroAddressNotAllowed");
        });

        it("should revert when input amount is not provide", async () => {
            await expect(erc20Swapper.swapEtherToToken(USDT, parseUnits("10000", 18))).to.be.revertedWithCustomError(erc20Swapper, "InsufficientInputAmount");
        });

        it("should revert when amount output is less than desired", async () => {
            await expect(erc20Swapper.swapEtherToToken(USDT, parseUnits("10000", 18), { value: parseUnits("1", 18) })).to.be.revertedWithCustomError(erc20Swapper, "OutputAmountBelowMinimum");
        });
    
        it("Should be able to swap eth to non-defltionary tokens", async () => {
            const previousUsdcBalance = await usdt.balanceOf(user.address);
            const tx = await erc20Swapper.swapEtherToToken(USDT, 0, { value: parseUnits("1", 18) });
            const currentUsdcBalance = await usdt.balanceOf(user.address);
    
            await expect(tx).emit(erc20Swapper, "SwapEtherToToken").withArgs(user.address, USDT, parseUnits("1", 18));
            expect(currentUsdcBalance).to.gt(previousUsdcBalance);
        });
    });

    describe("swapEtherToTokensWithSupportingFees", () => {
        it("should revert when amount output is less than desired", async () => {
            await expect(erc20Swapper.swapEtherToTokensWithSupportingFees(DTT, parseUnits("10000", 18), { value: parseUnits(".05", 18) })).to.be.revertedWithCustomError(erc20Swapper, "SwapAmountLessThanAmountOutMin");
        });

        it("Should revert when zero address is provided", async () => {
            await expect(erc20Swapper.swapEtherToTokensWithSupportingFees(ZERO_ADDRESS, 0)).to.be.revertedWithCustomError(erc20Swapper, "ZeroAddressNotAllowed");
        });

        it("Should be able to swap eth to defltionary tokens", async () => {
            const previousUsdcBalance = await dtt.balanceOf(user.address);
            const tx = await erc20Swapper.swapEtherToTokensWithSupportingFees(DTT, 0, { value: parseUnits(".05", 18) });
            const currentUsdcBalance = await dtt.balanceOf(user.address);
    
            await expect(tx).emit(erc20Swapper, "SwapEthToTokensAtSupportingFee").withArgs(user.address, DTT, parseUnits(".05", 18));
            expect(currentUsdcBalance).to.gt(previousUsdcBalance);
        });
    });
});