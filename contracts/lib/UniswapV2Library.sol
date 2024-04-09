//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IUniswapV2Pair} from "./../interfaces/IUniswapV2Pair.sol";

library UniswapV2Library {
    /**
     * @notice Error thrown if a zero address is passed
     */
    error ZeroAddress();

    /**
     * @notice Error thrown if two token addresses are identical
     */
    error IdenticalAddresses();

    /**
     * @notice Error thrown where the input amount parameter for a token is 0
     */
    error InsufficientInputAmount();

    /**
     * @notice Error thrown when the given reserves are equal to 0
     */
    error InsufficientLiquidity();

    /**
     * @notice Used to handle return values from pairs sorted in this order
     * @param tokenA The address of token A
     * @param tokenB The address of token B
     * @return token0 token1 Sorted token addresses
     */
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) {
            revert IdenticalAddresses();
        }
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        if (token0 == address(0)) {
            revert ZeroAddress();
        }
    }

    /**
     * @notice Calculates the CREATE2 address for a pair without making any external calls
     * @param factory Address of the uniswapv2 factory
     * @param tokenA The address of token A
     * @param tokenB The address of token B
     * @return pair Address for a pair
     */
    function getPair(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"4156ccc01dad273e6c65c4335c428a2ff4a4b0c95a9a228f6bfed45a069d3fe7" // init code hash
                        )
                    )
                )
            )
        );
    }

    /**
     * @notice Calculates the amount of token out.
     * @param pairAddress Address of the pair for tokenIn-tokenOut.
     * @param amountIn The amount of tokenIn to swap.
     * @param path Array with addresses of the underlying assets to be swapped
     * @return amounts Array of amounts after performing swap for respective pairs in path
     */
    function getAmountsOut(
        address pairAddress,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        (uint256 reserveIn, uint256 reserveOut) = getReserves(
            pairAddress,
            path[0],
            path[1]
        );
        amounts[1] = getAmountOut(amounts[0], reserveIn, reserveOut);
    }

    /**
     * @notice Fetches and sorts the reserves for a pair
     * @param pairAddress Address of the pair for token A and token B
     * @param tokenA The address of token A
     * @param tokenB The address of token B
     * @return reserveA reserveB Reserves for the token A and token B
     */
    function getReserves(
        address pairAddress,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pairAddress)
            .getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    /**
     * @notice Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
     * @param amountIn The amount of token A need to swap
     * @param reserveIn The amount of reserves for token A before swap
     * @param reserveOut The amount of reserves for token B after swap
     * @return amountOut The maximum output amount of the token B
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) {
            revert InsufficientInputAmount();
        } else if (reserveIn == 0 || reserveOut == 0) {
            revert InsufficientLiquidity();
        }
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
