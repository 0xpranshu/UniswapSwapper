//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {SafeERC20Upgradeable, IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {UniswapV2Library} from "./lib/UniswapV2Library.sol";

import {IWETH} from "./interfaces/IWETH.sol";
import {IERC20Swapper} from "./interfaces/IERC20Swapper.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";

contract ERC20Swapper is IERC20Swapper, Initializable, Ownable2StepUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @notice Thrown when zero address is provided.
     */
    error ZeroAddressNotAllowed();

    /**
     * @notice Error thrown when the amount received from a trade is below the minimum.
     */
    error OutputAmountBelowMinimum(uint256 amountOut, uint256 amountOutMin);

    /**
     * @notice Error thrown when swapamount is less than the amountOutmin
     */
    error SwapAmountLessThanAmountOutMin(
        uint256 swapAmount,
        uint256 amountOutMin
    );

    /**
     * @notice Events emit on the updation of factory address
     */
    event FactoryAddressUpdated(
        address indexed oldFactoryAddress,
        address indexed newFactoryAddress
    );

    /**
     * @notice Event emits on calling swapEtherToToken function.
     */
    event SwapEtherToToken(
        address indexed user,
        address indexed tokenOut,
        uint256 inputAmount
    );

    /**
     * @notice Event emits on calling swapEtherToTokensWithSupportingFees function.
     */
    event SwapEthToTokensAtSupportingFee(
        address indexed user,
        address indexed tokenOut,
        uint256 inputAmount
    );

    /**
     * @notice Stores WETH address.
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    address public immutable WETH;

    /**
     * @notice Stores uniswapv2 factory address.
     */
    address public factory;

    /**
     * @dev Modifier to ensure an address is not the zero address.
     * @param _address The address to check.
     */
    modifier ensureNonZeroAddress(address _address) {
        if (_address == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        _;
    }

    /**
     * @notice Constructs the ERC20Swapper contract.
     * @param _weth Address of the WETH token contract.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address _weth) ensureNonZeroAddress(_weth) {
        WETH = _weth;

        _disableInitializers();
    }

    /**
     * @notice Initializes the ERC20Swapper contract.
     * @param _uniswapv2Factory Address of the uniswapv2router.
     */
    function initialize(
        address _uniswapv2Factory
    ) external ensureNonZeroAddress(_uniswapv2Factory) initializer {
        factory = _uniswapv2Factory;
        __Ownable2Step_init();
    }

    /**
     * @notice Function to update the address of a factory contract.
     * This function can only be called by the owner of the contract.
     * @param newFactoryAddress Address of the new factory contract.
     * @custom:event FactoryAddressUpdated emits on success.
     */
    function setFactoryAddress(
        address newFactoryAddress
    ) external ensureNonZeroAddress(newFactoryAddress) onlyOwner {
        emit FactoryAddressUpdated(factory, newFactoryAddress);
        factory = newFactoryAddress;
    }

    /**
     * @notice Swaps Ether for an ERC20 token.
     * @param token The ERC20 token address to swap to.
     * @param amountOutMin The minimum amount of tokens to accept from the swap.
     * @return amount The amount of tokens received from the swap.
     * @custom:event SwapEtherToToken emits on success.
     */
    function swapEtherToToken(
        address token,
        uint256 amountOutMin
    ) external payable ensureNonZeroAddress(token) returns (uint256 amount) {
        uint256[] memory amounts = _swapExactETHToTokens(
            amountOutMin,
            token,
            msg.sender,
            TypesOfTokens.NON_SUPPORTING_FEE
        );

        amount = amounts[1];
    }

    /**
     * @notice Swaps Ether for an ERC20 token.
     * This method to swap deflationary tokens which would require supporting fee.
     * @param token The ERC20 token address to swap to.
     * @param amountOutMin The minimum amount of tokens to accept from the swap.
     * @return amount The amount of tokens received from the swap.
     * @custom:event SwapEtherToToken emits on success.
     */
    function swapEtherToTokensWithSupportingFees(
        address token,
        uint256 amountOutMin
    ) external payable ensureNonZeroAddress(token) returns (uint256 amount) {
        uint256 balanceBefore = IERC20Upgradeable(token).balanceOf(msg.sender);
        _swapExactETHToTokens(
            amountOutMin,
            token,
            msg.sender,
            TypesOfTokens.SUPPORTING_FEE
        );

        amount = _checkForAmountOut(
            token,
            balanceBefore,
            amountOutMin,
            msg.sender
        );
    }

    /**
     * @notice Swaps exact ETH for tokenOut.
     * @param amountOutMin Minimum amount of tokens to receive after swap.
     * @param to Address of the recipient of the tokenOut.
     * @param swapFor TypesOfTokens, either supporing fee or non supporting fee.
     * @return amounts Array of amounts after performing swap for respective pairs in path
     */
    function _swapExactETHToTokens(
        uint256 amountOutMin,
        address tokenOut,
        address to,
        TypesOfTokens swapFor
    ) internal returns (uint256[] memory amounts) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = tokenOut;

        IWETH(WETH).deposit{value: msg.value}();
        address pairAddress = UniswapV2Library.getPair(
            factory,
            path[0],
            path[1]
        );
        IERC20Upgradeable(WETH).safeTransfer(pairAddress, msg.value);

        if (swapFor == TypesOfTokens.NON_SUPPORTING_FEE) {
            amounts = UniswapV2Library.getAmountsOut(
                pairAddress,
                msg.value,
                path
            );
            if (amounts[1] < amountOutMin) {
                revert OutputAmountBelowMinimum(amounts[1], amountOutMin);
            }

            _swap(amounts, path, pairAddress, to);
            emit SwapEtherToToken(msg.sender, path[1], msg.value);
        } else {
            _swapSupportingFeeOnTransferTokens(path, pairAddress, to);
            emit SwapEthToTokensAtSupportingFee(msg.sender, path[1], msg.value);
        }
    }

    /**
     * @notice Perform swap on the path(pairs).
     * @param amounts Araay of amounts of tokens after performing the swap.
     * @param path Array with addresses of the underlying assets to be swapped.
     * @param _to Recipient of the output tokens.
     */
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address pairAddress,
        address _to
    ) internal {
        (address input, address output) = (path[0], path[1]);
        (address token0, ) = UniswapV2Library.sortTokens(input, output);

        uint256 amountOut = amounts[1];
        (uint256 amount0Out, uint256 amount1Out) = input == token0
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        IUniswapV2Pair(pairAddress).swap(
            amount0Out,
            amount1Out,
            _to,
            new bytes(0)
        );
    }

    /**
     * @notice Perform swap on the path(pairs) for supporting fee
     * @dev requires the initial amount to have already been sent to the first pair
     * @param path Array with addresses of the underlying assets to be swapped
     * @param _to Recipient of the output tokens.
     */
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        address pairAddress,
        address _to
    ) internal {
        (address input, address output) = (path[0], path[1]);
        (address token0, ) = UniswapV2Library.sortTokens(input, output);

        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        uint256 amountInput;
        uint256 amountOutput;
        {
            // scope to avoid stack too deep errors
            (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
            (uint256 reserveInput, uint256 reserveOutput) = input == token0
                ? (reserve0, reserve1)
                : (reserve1, reserve0);

            uint256 balance = IERC20Upgradeable(input).balanceOf(address(pair));
            amountInput = balance - reserveInput;
            amountOutput = UniswapV2Library.getAmountOut(
                amountInput,
                reserveInput,
                reserveOutput
            );
        }

        (uint256 amount0Out, uint256 amount1Out) = input == token0
            ? (uint256(0), amountOutput)
            : (amountOutput, uint256(0));

        pair.swap(amount0Out, amount1Out, _to, new bytes(0));
    }

    /**
     * @notice Check if the balance of to minus the balanceBefore is greater or equal to the amountOutMin.
     * @param asset The address of the underlying token
     * @param balanceBefore Balance before the swap.
     * @param amountOutMin Min amount out threshold.
     * @param to Recipient of the output tokens.
     * @return swapAmount Amount received after swap.
     */
    function _checkForAmountOut(
        address asset,
        uint256 balanceBefore,
        uint256 amountOutMin,
        address to
    ) internal view returns (uint256 swapAmount) {
        uint256 balanceAfter = IERC20Upgradeable(asset).balanceOf(to);
        swapAmount = balanceAfter - balanceBefore;
        if (swapAmount < amountOutMin) {
            revert SwapAmountLessThanAmountOutMin(swapAmount, amountOutMin);
        }
    }
}
