// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface ILendingPool {
    function borrow(
        address token,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
    function repay(
        address token,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external;
}

contract MarginTrading {
    IUniswapV2Router02 public uniswapRouter;
    ILendingPool[] public lendingPools;
    IERC20 public baseToken;
    address public trader;

    struct Positions {
        address[] allTokens;
        mapping(address => uint256) borrowed;
        mapping(address => uint256) holdings;
    }

    Positions public positions;

    modifier onlyTrader() {
        require(msg.sender == trader, "Not authorized");
        _;
    }

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, address indexed asset, uint256 amount);
    event Repaid(address indexed user, address indexed asset, uint256 amount);
    event TradeExecuted(
        address indexed user,
        address indexed inputAsset,
        address indexed outputAsset,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(
        address _uniswapRouter,
        address _lendingPool,
        address _baseToken,
        address _trader
    ) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        lendingPool = ILendingPool(_lendingPool);
        baseToken = IERC20(_baseToken);
        trader = _trader;
    }

    function depositCollateral(uint256 amount) external onlyTrader {
        baseToken.transferFrom(msg.sender, address(this), amount);
        positions.holdings[address(baseToken)] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external onlyTrader {
        require(
            positions.holdings[address(baseToken)] >= amount,
            "Insufficient collateral"
        );
        require(getDebtValue() == 0, "Outstanding debt must be repaid first");

        positions.holdings[address(baseToken)] -= amount;
        baseToken.transfer(trader, amount);
        emit CollateralWithdrawn(trader, amount);
    }

    function borrowAsset(address asset, uint256 amount) external onlyTrader {
        uint256 collateralValue = getCollateralValue();
        uint256 maxBorrow = collateralValue * 0.75; // 75% Loan-to-Value ratio
        require(
            amount + getDebtValue() <= maxBorrow,
            "Borrow amount exceeds collateral value"
        );

        lendingPool.borrow(asset, amount, 1, 0, address(this));
        positions.borrowed[asset] += amount;
        emit Borrowed(trader, asset, amount);
    }

    function repayAsset(address asset, uint256 amount) external onlyTrader {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(lendingPool), amount);
        lendingPool.repay(asset, amount, 1, address(this));
        positions.borrowed[asset] -= amount;
        emit Repaid(trader, asset, amount);
    }

    function executeTrade(
        address inputAsset,
        address outputAsset,
        uint256 amountIn,
        uint256 amountOutMin
    ) external onlyTrader {
        IERC20(inputAsset).transferFrom(msg.sender, address(this), amountIn);
        IERC20(inputAsset).approve(address(uniswapRouter), amountIn);

        address[] memory path = new address[](2);
        path[0] = inputAsset;
        path[1] = outputAsset;

        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this), // Lock tokens in the contract
            block.timestamp
        );

        positions.holdings[outputAsset] += amounts[1];
        emit TradeExecuted(
            trader,
            inputAsset,
            outputAsset,
            amountIn,
            amounts[1]
        );
    }

    function closePosition(address asset, uint256 amount) external onlyTrader {
        require(positions.holdings[asset] >= amount, "Insufficient holdings");

        positions.holdings[asset] -= amount;
        IERC20(asset).transfer(trader, amount);
    }

    function getCollateralValue() internal view returns (uint256) {
        return positions.collateral;
    }

    function getBaseValue(
        address token,
        uint256 amount
    ) internal view returns (uint256) {
        if (token == address(baseToken)) {
            return amount;
        }
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(baseToken);

        uint[] memory amounts = uniswapRouter.getAmountsOut(amount, path);
        return amounts[1];
    }

    function calculateDebtValue() internal view returns (uint256) {
        uint256 totalDebt = 0;
        // Iterate through all borrowed assets to calculate the total debt
        for (uint i = 0; i < positions.allTokens.length; i++) {
            address token = ositions.allTokens[i];
            uint256 debtAmount = positions.borrowed[token];
            if (debtAmount > 0) {
                totalDebt += getBaseValue(token, debtAmount);
            }
        }
        return totalDebt;
    }

    function calculateAssetValue() external view returns (uint256) {
        uint256 totalHoldingsValue = 0;
        for (uint i = 0; i < positions.allTokens.length; i++) {
            address token = ositions.allTokens[i];
            uint256 holdingAmount = positions.holdings[token];
            if (holdingAmount > 0) {
                totalHoldingsValue += getBaseValue(token, holdingAmount);
            }
        }
        return totalHoldingsValue;
    }
}
