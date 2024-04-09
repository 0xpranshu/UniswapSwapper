//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IERC20Swapper {
    /**
     * @notice @notice Select the type of Token for which either a supporting fee would be deducted or not at the time of transfer.
     */
    enum TypesOfTokens {
        NON_SUPPORTING_FEE,
        SUPPORTING_FEE
    }

    /**
     * @dev swaps the `msg.value` Ether to at least `minAmount` of tokens in `address`, or reverts.
     * @param token The address of ERC-20 token to swap.
     * @param minAmount The minimum amount of tokens transferred to msg.sender.
     */
    function swapEtherToToken(
        address token,
        uint minAmount
    ) external payable returns (uint256);
}
