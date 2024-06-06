// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FFCurrencySwap {
    // Fixed-for-Fixed Currency Swap (ERC20-ERC20)

    address public owner; // Swap dealer/Market Maker
    address public partyA; // token A
    address public partyB; // token B
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint256 public tokenANotional;
    uint256 public tokenBNotional;
    uint256 public tokenARateBps;
    uint256 public tokenBRateBps;

    uint256 public tokenAInitMargin; // recommand: 2 * Notional * (SwapRate + feeRate)
    uint256 public tokenBInitMargin; // recommand: 2 * Notional * (SwapRate + feeRate)
    uint256 public tokenAMaintenanceMargin; // recommand: 4 * Notional * (SwapRate + feeRate)
    uint256 public tokenBMaintenanceMargin; // recommand: 4 * Notional * (SwapRate + feeRate)
    uint256 public marketMakerFeeBps; // Market Maker Fee in base points of notionals

    uint256 public paymentInterval;
    uint256 public totalDuration;

    uint256 public lastPaymentTime;
    uint256 public startTime;
    bool public swapStarted;

    constructor() {
        owner = msg.sender;
    }

    function setSwap(
        address _partyA,
        address _partyB,
        address _tokenA,
        address _tokenB,
        uint256 _tokenANotional,
        uint256 _tokenBNotional,
        uint256 _tokenARateBps,
        uint256 _tokenBRateBps,
        uint256 _tokenAInitMargin,
        uint256 _tokenBInitMargin,
        uint256 _tokenAMaintenanceMargin,
        uint256 _tokenBMaintenanceMargin,
        uint256 _marketMakerFeeBps,
        uint256 _paymentInterval,
        uint256 _totalDuration
    ) external {
        require(msg.sender == owner, "Only owner can call this function");
        require(swapStarted = false, "Cannot reset swap, the swap is started");
        if (tokenA.balanceOf(address(this)) > 0) {
            tokenA.transfer(partyA, tokenA.balanceOf(address(this)));
        }
        if (tokenB.balanceOf(address(this)) > 0) {
            tokenB.transfer(partyB, tokenB.balanceOf(address(this)));
        }
        partyA = _partyA;
        partyB = _partyB;
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        tokenANotional = _tokenANotional;
        tokenBNotional = _tokenBNotional;
        tokenARateBps = _tokenARateBps;
        tokenBRateBps = _tokenBRateBps;

        tokenAInitMargin = _tokenAInitMargin;
        tokenBInitMargin = _tokenBInitMargin;
        tokenAMaintenanceMargin = _tokenAMaintenanceMargin;
        tokenBMaintenanceMargin = _tokenBMaintenanceMargin;
        marketMakerFeeBps = _marketMakerFeeBps;

        paymentInterval = _paymentInterval;
        totalDuration = _totalDuration;

        swapStarted = false;
    }

    function startSwap() external {
        require(
            tokenA.balanceOf(address(this)) > tokenAInitMargin &&
                tokenB.balanceOf(address(this)) > tokenBInitMargin,
            "Initial margin is not sufficient"
        );
        swapStarted = true;
        startTime = block.timestamp;
        lastPaymentTime = block.timestamp;
    }

    function depositTokenAMargin(uint256 depositeValue) external payable {
        require(
            msg.sender == partyA,
            "Only Party A can deposit Token A margin"
        );
        require(
            tokenA.transferFrom(msg.sender, address(this), depositeValue),
            "erc20 margin transfer failed"
        );
    }

    function depositTokenBMargin(uint256 depositeValue) external {
        require(
            msg.sender == partyB,
            "Only Party B can deposit Token B margin"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), depositeValue),
            "erc20 margin transfer failed"
        );
    }

    function makePayment() external {
        require(swapStarted, "Swap has not started");
        require(
            block.timestamp >= lastPaymentTime + paymentInterval,
            "Payment interval has not passed"
        );
        require(
            block.timestamp < startTime + totalDuration,
            "Swap duration has ended"
        );

        // Collect market maker fees from both parties
        tokenA.transfer(owner, (tokenANotional * marketMakerFeeBps) / 10000);
        tokenB.transfer(owner, (tokenBNotional * marketMakerFeeBps) / 10000);

        // Make payment for parties
        uint256 tokenAPayment = (tokenANotional * tokenARateBps) / 10000;
        uint256 tokenBPayment = (tokenBNotional * tokenBRateBps) / 10000;

        require(
            tokenA.transfer(partyA, tokenAPayment),
            "tokenA payment transfer failed"
        );
        require(
            tokenB.transfer(partyB, tokenBPayment),
            "tokenB payment transfer failed"
        );

        lastPaymentTime = block.timestamp;
    }

    function endSwap() external {
        require(swapStarted, "Swap has not started");
        require(
            block.timestamp >= startTime + totalDuration,
            "Swap duration has not ended"
        );

        // Collect market maker fees from both parties
        tokenA.transfer(owner, (tokenANotional * marketMakerFeeBps) / 10000);
        tokenB.transfer(owner, (tokenBNotional * marketMakerFeeBps) / 10000);
        // Refund remaining margins
        require(
            tokenA.transfer(partyA, tokenA.balanceOf(address(this))),
            "erc20 margin transfer failed"
        );
        require(
            tokenB.transfer(partyB, tokenB.balanceOf(address(this))),
            "erc20 margin transfer failed"
        );

        swapStarted = false;
    }

    function partyALiqudation() external {
        require(
            tokenA.balanceOf(address(this)) < tokenAMaintenanceMargin,
            "Hasn't reached the liqudation level"
        );
        tokenA.transfer(owner, tokenA.balanceOf(address(this)) / 2);
        tokenA.transfer(partyB, tokenA.balanceOf(address(this)) / 2);
        tokenB.transfer(partyB, tokenB.balanceOf(address(this)));

        swapStarted = false;
    }

    function partyBLiqudation() external {
        require(
            tokenB.balanceOf(address(this)) < tokenBMaintenanceMargin,
            "Hasn't reached the liqudation level"
        );
        tokenB.transfer(owner, tokenB.balanceOf(address(this)) / 2);
        tokenB.transfer(partyA, tokenB.balanceOf(address(this)) / 2);
        tokenA.transfer(partyA, tokenA.balanceOf(address(this)));

        swapStarted = false;
    }
}
