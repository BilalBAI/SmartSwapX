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
    address public partyA;
    address public partyB;
    uint256 public ethNotional;
    uint256 public erc20Notional;
    uint256 public ethRate;
    uint256 public erc20Rate;
    uint256 public paymentInterval;
    uint256 public totalDuration;
    uint256 public startTime;
    IERC20 public erc20Token;
    bool public swapStarted;

    uint256 public lastPaymentTime;
    uint256 public ethMargin;
    uint256 public erc20Margin;

    bool public ethMarginDeposited;
    bool public erc20MarginDeposited;

    constructor(
        address _partyA,
        address _partyB,
        uint256 _ethNotional,
        uint256 _erc20Notional,
        uint256 _ethRate,
        uint256 _erc20Rate,
        uint256 _paymentInterval,
        uint256 _totalDuration,
        address _erc20Token,
        uint256 _ethMargin,
        uint256 _erc20Margin
    ) {
        partyA = _partyA;
        partyB = _partyB;
        ethNotional = _ethNotional;
        erc20Notional = _erc20Notional;
        ethRate = _ethRate;
        erc20Rate = _erc20Rate;
        paymentInterval = _paymentInterval;
        totalDuration = _totalDuration;
        erc20Token = IERC20(_erc20Token);
        ethMargin = _ethMargin;
        erc20Margin = _erc20Margin;
        swapStarted = false;
        ethMarginDeposited = false;
        erc20MarginDeposited = false;
    }

    function depositEthMargin() external payable {
        require(msg.sender == partyA, "Only Party A can deposit ETH margin");
        require(msg.value == ethMargin, "Incorrect ETH margin amount");
        require(!ethMarginDeposited, "ETH margin already deposited");

        ethMarginDeposited = true;

        if (ethMarginDeposited && erc20MarginDeposited) {
            swapStarted = true;
            startTime = block.timestamp;
            lastPaymentTime = block.timestamp;
        }
    }

    function depositerc20Margin() external {
        require(msg.sender == partyB, "Only Party B can deposit erc20 margin");
        require(
            erc20Token.transferFrom(msg.sender, address(this), erc20Margin),
            "erc20 margin transfer failed"
        );
        require(!erc20MarginDeposited, "erc20 margin already deposited");

        erc20MarginDeposited = true;

        if (ethMarginDeposited && erc20MarginDeposited) {
            swapStarted = true;
            startTime = block.timestamp;
            lastPaymentTime = block.timestamp;
        }
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

        uint256 ethPayment = (ethNotional * ethRate) / 100;
        uint256 erc20Payment = (erc20Notional * erc20Rate) / 100;

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

        // Refund remaining margins
        payable(partyA).transfer(address(this).balance);
        require(
            erc20Token.transfer(partyB, erc20Token.balanceOf(address(this))),
            "erc20 margin transfer failed"
        );

        swapStarted = false;
    }
}
