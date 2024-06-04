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

contract FixedForFixedCurrencySwap {
    address public owner; // Swap dealer/Market Maker
    address public partyA; // ETH
    address public partyB; // ERC-20 token
    uint256 public ethNotional;
    uint256 public erc20Notional;
    uint256 public ethRateBps;
    uint256 public erc20RateBps;
    uint256 public paymentInterval;
    uint256 public totalDuration;
    uint256 public startTime;
    IERC20 public erc20Token;
    bool public swapStarted;

    uint256 public lastPaymentTime;
    uint256 public ethInitMargin;
    uint256 public erc20InitMargin;
    uint256 public ethMaintenanceMargin;
    uint256 public erc20MaintenanceMargin;
    uint256 public marketMakerFeeBps; // Market Maker Fee in base points of notionals

    constructor() {
        owner = msg.sender;
    }

    function setSwap(
        address _partyA,
        address _partyB,
        uint256 _ethNotional,
        uint256 _erc20Notional,
        uint256 _ethRateBps,
        uint256 _erc20RateBps,
        uint256 _paymentInterval,
        uint256 _totalDuration,
        address _erc20Token,
        uint256 _ethInitMargin,
        uint256 _erc20InitMargin,
        uint256 _ethMaintenanceMargin
        uint256 _erc20MaintenanceMargin
        uint256 _marketMakerFeeBps,
    ) external {
        require(msg.sender == owner, "Only owner can call this function");
        require(swapStarted = false, "Cannot reset swap, the swap is started");
        partyA = _partyA;
        partyB = _partyB;
        ethNotional = _ethNotional;
        erc20Notional = _erc20Notional;
        ethRateBps = _ethRateBps;
        erc20RateBps = _erc20RateBps;
        paymentInterval = _paymentInterval;
        totalDuration = _totalDuration;
        erc20Token = IERC20(_erc20Token);
        ethInitMargin = _ethInitMargin;
        erc20InitMargin = _erc20InitMargin;
        ethMaintenanceMargin = _ethMaintenanceMargin
        erc20MaintenanceMargin = _erc20MaintenanceMargin
        marketMakerFeeBps = _marketMakerFeeBps;
        swapStarted = false;
        ethInitMarginDeposited = false;
        erc20InitMarginDeposited = false;
    }

    function startSwap() external {
        require(
            address(this).balance > ethInitMargin && erc20Token.balanceOf(address(this)) > erc20InitMargin,
            "Initial margin is not sufficient"
        );
        swapStarted = true;
        startTime = block.timestamp;
        lastPaymentTime = block.timestamp;
    }

    function depositEthMargin() external payable {
        require(msg.sender == partyA, "Only Party A can deposit ETH margin");
        require(msg.value > 0, "Deposite value must > 0");
        //msg.value
    }

    function depositErc20Margin(uint256 depositeValue) external {
        require(msg.sender == partyB, "Only Party B can deposit erc20 margin");
        require(
            erc20Token.transferFrom(msg.sender, address(this), depositeValue),
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
        payable(owner).transfer(ethNotional * marketMakerFeeBps / 10000);
        erc20Token.transfer(owner, erc20Notional * marketMakerFeeBps / 10000)

        // Make payment for parties
        uint256 ethPayment = (ethNotional * ethRateBps) / 10000;
        uint256 erc20Payment = (erc20Notional * erc20RateBps) / 10000;

        require(
            address(this).balance >= ethPayment,
            "Insufficient ETH in contract"
        );
        require(
            erc20Token.balanceOf(address(this)) >= erc20Payment,
            "Insufficient erc20 in contract"
        );

        payable(partyB).transfer(ethPayment);
        require(
            erc20Token.transfer(partyA, erc20Payment),
            "erc20 payment transfer failed"
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
        payable(owner).transfer(ethNotional * marketMakerFeeBps / 10000);
        erc20Token.transfer(owner, erc20Notional * marketMakerFeeBps / 10000)
        // Refund remaining margins
        payable(partyA).transfer(address(this).balance);
        require(
            erc20Token.transfer(partyB, erc20Token.balanceOf(address(this))),
            "erc20 margin transfer failed"
        );

        swapStarted = false;
    }

    function partyALiqudation() external {
        require(address(this).balance < ethMaintenanceMargin, "Hasn't reached the liqudation level");
        payable(owner).transfer(address(this).balance/2);
        payable(partyB).transfer(address(this).balance/2);
        erc20Token.transfer(partyB, erc20Token.balanceOf(address(this)));
        swapStarted = false;
    }

    function partyBLiqudation() external {
        require(erc20Token.balanceOf(address(this)) < erc20MaintenanceMargin, "Hasn't reached the liqudation level");
        erc20Token.transfer(owner, erc20Token.balanceOf(address(this))/2);
        erc20Token.transfer(partyA, erc20Token.balanceOf(address(this))/2);
        payable(partyA).transfer(address(this).balance);
        swapStarted = false;
    }
}
