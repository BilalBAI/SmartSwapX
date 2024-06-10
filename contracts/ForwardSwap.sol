// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ForwardSwap is Ownable {
    /* 
       A forward swap enables parties to exchange token flows 
       according to a predetermined schedule in the future.
    */
    address public partyA; // party that holds token A and want to receive token B
    address public partyB; //  party that holds token B and want to receive token A
    IERC20 public tokenA; // ERC-20 token address
    IERC20 public tokenB; // ERC-20 token address
    uint256 public tokenANotional; // Token A amount to be transfered to the party B in each payment
    uint256 public tokenBNotional; // Token B amount to be transfered to the party A in each payment

    uint256 public tokenAInitMargin; // recommand: 4 * Notional
    uint256 public tokenBInitMargin; // recommand: 4 * Notional
    uint256 public tokenAMaintenanceMargin; // recommand: 2 * Notional
    uint256 public tokenBMaintenanceMargin; // recommand: 2 * Notional
    uint256 public marketMakerFeeBps; // Market maker/dealer fee in base points for each payment

    uint256 public paymentInterval; // in seconds
    uint256 public totalDuration; // in seconds

    uint256 public lastPaymentTime;
    uint256 public startTime;
    bool public swapStarted;
    bool public partyATerminationConsent;
    bool public partyBTerminationConsent;

    event SwapSet(address indexed partyA, address indexed partyB);
    event SwapMarginAndFeeSet(
        uint256 tokenAInitMargin,
        uint256 tokenBInitMargin,
        uint256 tokenAMaintenanceMargin,
        uint256 tokenBMaintenanceMargin,
        uint256 marketMakerFeeBps
    );
    event SwapStarted(uint256 startTime);
    event MarginDeposited(address indexed party, uint256 amount);
    event MarginWithdrawed(address indexed party);
    event PaymentMade(
        uint256 tokenAPayment,
        uint256 tokenBPayment,
        uint256 lastPaymentTime
    );
    event SwapEnded();
    event PartyALiquidated(uint256 amount);
    event PartyBLiquidated(uint256 amount);

    constructor() Ownable(msg.sender) {
        // Swap dealer/Market Maker
    }

    function setSwap(
        address _partyA,
        address _partyB,
        address _tokenA,
        address _tokenB,
        uint256 _tokenANotional,
        uint256 _tokenBNotional,
        uint256 _paymentInterval,
        uint256 _totalDuration
    ) external onlyOwner {
        require(!swapStarted, "Cannot reset swap, the swap has started");

        // Transfer existing balances back to respective parties if they exist
        if (
            address(tokenA) != address(0) && tokenA.balanceOf(address(this)) > 0
        ) {
            tokenA.transfer(partyA, tokenA.balanceOf(address(this)));
        }
        if (
            address(tokenB) != address(0) && tokenB.balanceOf(address(this)) > 0
        ) {
            tokenB.transfer(partyB, tokenB.balanceOf(address(this)));
        }

        require(
            _partyA != address(0) && _partyB != address(0),
            "Invalid party address"
        );
        require(
            _tokenA != address(0) && _tokenB != address(0),
            "Invalid token address"
        );
        require(
            _tokenANotional > 0 && _tokenBNotional > 0,
            "Notional amounts must be greater than zero"
        );

        partyA = _partyA;
        partyB = _partyB;
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        tokenANotional = _tokenANotional;
        tokenBNotional = _tokenBNotional;
        paymentInterval = _paymentInterval;
        totalDuration = _totalDuration;

        swapStarted = false;
        partyATerminationConsent = false;
        partyBTerminationConsent = false;

        emit SwapSet(_partyA, _partyB);
    }

    function setMarginFee(
        uint256 _tokenAInitMargin,
        uint256 _tokenBInitMargin,
        uint256 _tokenAMaintenanceMargin,
        uint256 _tokenBMaintenanceMargin,
        uint256 _marketMakerFeeBps
    ) external onlyOwner {
        require(!swapStarted, "Cannot reset swap, the swap has started");
        tokenAInitMargin = _tokenAInitMargin;
        tokenBInitMargin = _tokenBInitMargin;
        tokenAMaintenanceMargin = _tokenAMaintenanceMargin;
        tokenBMaintenanceMargin = _tokenBMaintenanceMargin;
        marketMakerFeeBps = _marketMakerFeeBps;

        emit SwapMarginAndFeeSet(
            tokenAInitMargin,
            tokenBInitMargin,
            tokenAMaintenanceMargin,
            tokenBMaintenanceMargin,
            marketMakerFeeBps
        );
    }

    function startSwap() external onlyOwner {
        require(
            tokenA.balanceOf(address(this)) >= tokenAInitMargin &&
                tokenB.balanceOf(address(this)) >= tokenBInitMargin,
            "Initial margin is not sufficient"
        );
        swapStarted = true;
        startTime = block.timestamp;
        lastPaymentTime = block.timestamp;

        emit SwapStarted(startTime);
    }

    function depositMarginTokenA(uint256 depositValue) external {
        require(
            msg.sender == partyA,
            "Only Party A can deposit Token A margin"
        );
        require(
            tokenA.transferFrom(msg.sender, address(this), depositValue),
            "ERC20 margin transfer failed"
        );

        emit MarginDeposited(partyA, depositValue);
    }

    function withdrawMarginTokenA() external {
        require(
            msg.sender == partyA,
            "Only Party A can withdraw Token A margin"
        );
        require(!swapStarted, "Cannot withdraw: Swap has started");
        require(
            tokenA.transfer(msg.sender, tokenA.balanceOf(address(this))),
            "ERC20 margin transfer failed"
        );

        emit MarginWithdrawed(partyA);
    }

    function depositMarginTokenB(uint256 depositValue) external {
        require(
            msg.sender == partyB,
            "Only Party B can deposit Token B margin"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), depositValue),
            "ERC20 margin transfer failed"
        );

        emit MarginDeposited(partyB, depositValue);
    }

    function withdrawMarginTokenB() external {
        require(
            msg.sender == partyB,
            "Only Party B can withdraw Token B margin"
        );
        require(!swapStarted, "Cannot withdraw: Swap has started");
        require(
            tokenB.transfer(msg.sender, tokenB.balanceOf(address(this))),
            "ERC20 margin transfer failed"
        );

        emit MarginWithdrawed(partyB);
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

        // Make fee payments to market maker from both parties
        tokenA.transfer(owner(), (tokenANotional * marketMakerFeeBps) / 10000);
        tokenB.transfer(owner(), (tokenBNotional * marketMakerFeeBps) / 10000);
        // !!! Solidity doesn't handle floating numbers, notional * (1000 / 10000) = notional * 0 = 0

        // Make payments to parties
        require(
            tokenA.transfer(partyB, tokenANotional),
            "TokenA payment transfer failed"
        ); // transfer token A to party B
        require(
            tokenB.transfer(partyA, tokenBNotional),
            "TokenB payment transfer failed"
        ); // transfer token B to party A

        lastPaymentTime = block.timestamp;

        emit PaymentMade(tokenANotional, tokenBNotional, lastPaymentTime);
    }

    function endSwap() external {
        require(swapStarted, "Swap has not started");
        require(
            block.timestamp >= startTime + totalDuration,
            "Swap duration has not ended"
        );

        // Collect market maker fees from both parties
        tokenA.transfer(owner(), (tokenANotional * marketMakerFeeBps) / 10000);
        tokenB.transfer(owner(), (tokenBNotional * marketMakerFeeBps) / 10000);

        // Refund remaining margins
        uint256 remainingA = tokenA.balanceOf(address(this));
        uint256 remainingB = tokenB.balanceOf(address(this));

        if (remainingA > 0) {
            require(
                tokenA.transfer(partyA, remainingA),
                "ERC20 margin transfer failed for party A"
            );
        }
        if (remainingB > 0) {
            require(
                tokenB.transfer(partyB, remainingB),
                "ERC20 margin transfer failed for party B"
            );
        }

        swapStarted = false;

        emit SwapEnded();
    }

    function Liquidation() external {
        require(
            tokenA.balanceOf(address(this)) < tokenAMaintenanceMargin ||
                tokenB.balanceOf(address(this)) < tokenBMaintenanceMargin,
            "None of the parties has reached the liquidation level"
        );

        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));

        // Liquidate party A if below Maintenance Margin
        if (balanceA < tokenAMaintenanceMargin) {
            tokenA.transfer(owner(), balanceA / 2);
            tokenA.transfer(partyB, balanceA / 2);
            emit PartyALiquidated(balanceA);
            balanceA = 0;
        }

        // Liquidate party B if below Maintenance Margin
        if (balanceB < tokenBMaintenanceMargin) {
            tokenB.transfer(owner(), balanceB / 2);
            tokenB.transfer(partyA, balanceB / 2);
            emit PartyBLiquidated(balanceB);
            balanceB = 0;
        }

        // Refund the remaining
        if (balanceA != 0) {
            tokenA.transfer(partyA, balanceA);
        }
        if (balanceB != 0) {
            tokenB.transfer(partyB, balanceB);
        }

        swapStarted = false;
    }

    function terminateSwap() external {
        // Allow Party A and Party B together to terminate the swap after swap started.
        require(
            msg.sender == partyA || msg.sender == partyB,
            "Only parties involved can initiate termination"
        );
        require(swapStarted, "Swap has not started");

        // Both parties must call this function to agree on termination
        if (msg.sender == partyA) {
            partyATerminationConsent = true;
        } else if (msg.sender == partyB) {
            partyBTerminationConsent = true;
        }

        if (partyATerminationConsent && partyBTerminationConsent) {
            // Refund remaining margins
            uint256 remainingA = tokenA.balanceOf(address(this));
            uint256 remainingB = tokenB.balanceOf(address(this));

            if (remainingA > 0) {
                require(
                    tokenA.transfer(partyA, remainingA),
                    "ERC20 margin transfer failed for party A"
                );
            }
            if (remainingB > 0) {
                require(
                    tokenB.transfer(partyB, remainingB),
                    "ERC20 margin transfer failed for party B"
                );
            }

            // Reset the termination consents
            partyATerminationConsent = false;
            partyBTerminationConsent = false;

            swapStarted = false;

            emit SwapEnded();
        }
    }
}
