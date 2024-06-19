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
    uint public marginReqBps;

    struct Positions {
        address[] allTokens;
        mapping(address => uint256) debts;
        mapping(address => uint256) assets;
    }

    Positions public positions;

    modifier onlyTrader() {
        require(msg.sender == trader, "Not authorized");
        _;
    }

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, address indexed token, uint256 amount);
    event Repaid(address indexed user, address indexed token, uint256 amount);
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

    function deposit(uint256 amount) external onlyTrader {
        require(
            baseToken.transferFrom(msg.sender, address(this), amount),
            "Deposit failed"
        );
        positions.assets[address(baseToken)] += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external onlyTrader {
        require(getDebtValue() == 0, "Outstanding debt must be repaid first");
        require(
            positions.assets[address(baseToken)] >= amount,
            "Insufficient balance"
        );
        positions.assets[address(baseToken)] -= amount;
        baseToken.transfer(trader, amount);
        emit Withdrawn(trader, amount);
    }

    function borrowToken(address token, uint256 amount) external onlyTrader {
        borrowValue = getBaseValue(token, amount);
        uint256 MarginRatioBpsAdj = calculateMarginRatioBps(
            borrowValue,
            borrowValue
        );
        require(
            MarginRatioBpsAdj <= marginReqBps,
            "Borrow amount will exceeds required margin ratio"
        );
        lendingPool.borrow(token, amount, 1, 0, address(this));
        positions.debts[token] += amount;
        emit Borrowed(trader, token, amount);
    }

    function repayToken(address token, uint256 amount) external onlyTrader {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(address(lendingPool), amount);
        lendingPool.repay(token, amount, 1, address(this));
        positions.debts[token] -= amount;
        emit Repaid(trader, token, amount);
    }

    function trade(
        address inputToken,
        address outputToken,
        uint256 amountIn,
        uint256 amountOutMin
    ) external onlyTrader {
        // IERC20(inputToken).transferFrom(msg.sender, address(this), amountIn);
        // IERC20(inputToken).approve(address(uniswapRouter), amountIn);
        require(
            IERC20(inputToken).balanceOf(address(this)) >= amountIn,
            "Insufficient balance"
        );
        address[] memory path = new address[](2);
        path[0] = inputToken;
        path[1] = outputToken;

        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this), // Lock tokens in the contract
            block.timestamp
        );
        positions.assets[inputToken] -= amounts[0];
        positions.assets[outputToken] += amounts[1];
        emit TradeExecuted(
            trader,
            inputToken,
            outputToken,
            amountIn,
            amounts[1]
        );
    }

    function closePosition(address token, uint256 amount) external onlyTrader {
        require(positions.assets[token] >= amount, "Insufficient assets");

        positions.assets[token] -= amount;
        IERC20(token).transfer(trader, amount);
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
        uint256 totalDebtValue = 0;
        // Iterate through all borrowed assets to calculate the total debt
        for (uint i = 0; i < positions.allTokens.length; i++) {
            address token = ositions.allTokens[i];
            uint256 debtAmount = positions.debts[token];
            if (debtAmount > 0) {
                totalDebtValue += getBaseValue(token, debtAmount);
            }
        }
        return totalDebtValue;
    }

    function calculateAssetValue() external view returns (uint256) {
        uint256 totalAssetValue = 0;
        for (uint i = 0; i < positions.allTokens.length; i++) {
            address token = ositions.allTokens[i];
            uint256 holdingAmount = positions.assets[token];
            if (holdingAmount > 0) {
                totalAssetValue += getBaseValue(token, holdingAmount);
            }
        }
        return totalAssetValue;
    }

    function calculateMarginRatioBps(
        uint assetAdj,
        uint debtAdj
    ) external view returns (uint256) {
        uint totalAssetValue = calculateAssetValue();
        uint totalDebtValue = calculateDebtValue();
        marginRatioBps =
            ((totalAssetValue + assetAdj) * 10000) /
            (totalDebtValue + assetAdj);
        return marginRatioBps;
    }
}
