// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ForwardSwapV1 is Ownable {
    /*
        A forward swap enables parties to exchange token flows 
        according to a predetermined schedule in the future.
        Owner of this contract is the forward swap dealer/market maker
        that helps to facilitate the process and thus is entitled to a fee. 
        If there is no active dealer involved, the dealer fee can be set to zero.
    */

    // Swap parties
    address public partyA; // Party holding token A and wanting to receive token B
    address public partyB; // Party holding token B and wanting to receive token A

    // Swap details
    IERC20 public tokenA; // ERC-20 token A address
    IERC20 public tokenB; // ERC-20 token B address
    uint256 public tokenANotional; // Amount of token A to be transferred to party B in each payment
    uint256 public tokenBNotional; // Amount of token B to be transferred to party A in each payment
    uint256 public paymentInterval; // Payment interval in seconds
    uint256 public totalPaymentCount; // Total number of swap payments
    // uint256 public totalDuration; // Total swap duration in seconds

    // Margin and fees
    uint256 public tokenAInitMargin; // Initial Margin
    uint256 public tokenBInitMargin; // Initial Margin
    uint256 public tokenAMaintenanceMargin; // Maintenance Margin
    uint256 public tokenBMaintenanceMargin; // Maintenance Margin
    uint256 public marketMakerFeeBps; // Market maker/dealer fee in basis points for each payment

    // Swap state variables
    uint256 public paymentCount; // the number of payments has been made
    uint256 public lastPaymentTime; // Last payment timestamp
    uint256 public startTime; // Swap start timestamp
    bool public swapStarted; // Flag indicating if the swap has started
    bool public partyATerminationConsent; // Party A's termination consent
    bool public partyBTerminationConsent; // Party B's termination consent
    uint256 public feeA;
    uint256 public feeB;
    uint256 public liquidationLevelA;
    uint256 public liquidationLevelB;
    // Events
    event SwapSet();
    event PartiesSet(address indexed partyA, address indexed partyB);
    event SwapMarginAndFeeSet(
        uint256 liquidationLevelA,
        uint256 liquidationLevelB
    );
    event SwapStarted(uint256 startTime);
    event MarginDeposited(address indexed party, uint256 amount);
    event MarginWithdrawn(address indexed party);
    event PaymentMade(
        uint256 tokenAPayment,
        uint256 tokenBPayment,
        uint256 lastPaymentTime
    );
    event SwapEnded();
    event PartyALiquidated(uint256 amount);
    event PartyBLiquidated(uint256 amount);

    // Constructor to set the owner
    constructor() Ownable(msg.sender) {}

    // Restrictions
    modifier onlyPartyA() {
        require(msg.sender == partyA, "Cannot process: Only Party A");
        _;
    }
    modifier onlyPartyB() {
        require(msg.sender == partyB, "Cannot process: Only Party B");
        _;
    }
    modifier onlyNotStarted() {
        require(!swapStarted, "Cannot process: the swap has started");
        _;
    }
    modifier onlyStarted() {
        require(swapStarted, "Cannot process: Swap has not started");
        _;
    }

    // Set swap parameters
    function setSwap(
        address _tokenA,
        address _tokenB,
        uint256 _tokenANotional,
        uint256 _tokenBNotional,
        uint256 _paymentInterval,
        uint256 _totalPaymentCount
    ) external onlyOwner onlyNotStarted {
        refundBalance();

        require(
            _tokenANotional > 0 && _tokenBNotional > 0,
            "Notional amounts must be greater than zero"
        );

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        tokenANotional = _tokenANotional;
        tokenBNotional = _tokenBNotional;
        paymentInterval = _paymentInterval;
        totalPaymentCount = _totalPaymentCount;

        resetSwapState();
        emit SwapSet();
    }

    // Set swap parties
    function setParties(
        address _partyA,
        address _partyB
    ) external onlyOwner onlyNotStarted {
        require(
            _partyA != address(0) && _partyB != address(0),
            "Party addresses must be non-zero"
        );
        refundBalance();

        partyA = _partyA;
        partyB = _partyB;

        emit PartiesSet(_partyA, _partyB);
    }

    // Set margin and fee parameters
    function setMarginFee(
        uint256 _tokenAInitMargin,
        uint256 _tokenBInitMargin,
        uint256 _tokenAMaintenanceMargin,
        uint256 _tokenBMaintenanceMargin,
        uint256 _marketMakerFeeBps
    ) external onlyOwner onlyNotStarted {
        refundBalance();

        tokenAInitMargin = _tokenAInitMargin;
        tokenBInitMargin = _tokenBInitMargin;
        tokenAMaintenanceMargin = _tokenAMaintenanceMargin;
        tokenBMaintenanceMargin = _tokenBMaintenanceMargin;
        marketMakerFeeBps = _marketMakerFeeBps;
        // Calculate Dealer Fee
        feeA = (tokenANotional * marketMakerFeeBps) / 10000;
        feeB = (tokenBNotional * marketMakerFeeBps) / 10000;
        // Calculate liquidationLevel: Need to have sufficient balance
        // to cover MaintenanceMargin + fee + Notional for one payment
        liquidationLevelA = tokenAMaintenanceMargin + tokenANotional + feeA;
        liquidationLevelB = tokenBMaintenanceMargin + tokenBNotional + feeB;

        emit SwapMarginAndFeeSet(liquidationLevelA, liquidationLevelB);
    }

    // Start the swap
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

    // Deposit margin for Token A
    function depositMarginTokenA(uint256 depositValue) external onlyPartyA {
        require(
            tokenA.transferFrom(msg.sender, address(this), depositValue),
            "ERC20 margin transfer failed"
        );

        emit MarginDeposited(partyA, depositValue);
    }

    // Withdraw margin for Token A
    function withdrawMarginTokenA() external onlyPartyA onlyNotStarted {
        require(
            tokenA.transfer(msg.sender, tokenA.balanceOf(address(this))),
            "ERC20 margin transfer failed"
        );

        emit MarginWithdrawn(partyA);
    }

    // Deposit margin for Token B
    function depositMarginTokenB(uint256 depositValue) external onlyPartyB {
        require(
            tokenB.transferFrom(msg.sender, address(this), depositValue),
            "ERC20 margin transfer failed"
        );

        emit MarginDeposited(partyB, depositValue);
    }

    // Withdraw margin for Token B
    function withdrawMarginTokenB() external onlyPartyB onlyNotStarted {
        require(
            tokenB.transfer(msg.sender, tokenB.balanceOf(address(this))),
            "ERC20 margin transfer failed"
        );

        emit MarginWithdrawn(partyB);
    }

    // Make a scheduled payment
    function makePayment() external onlyStarted {
        require(
            block.timestamp >= lastPaymentTime + paymentInterval,
            "Payment interval has not passed"
        );
        require(
            paymentCount < totalPaymentCount,
            "All payments have been made"
        );

        if (
            tokenA.balanceOf(address(this)) < liquidationLevelA ||
            tokenB.balanceOf(address(this)) < liquidationLevelB
        ) {
            collectFees();
            liquidateSwap();
        } else {
            collectFees();
            processPayment();
        }
    }

    // End the swap after the total duration has passed
    function endSwap() external onlyStarted {
        require(
            paymentCount >= totalPaymentCount,
            "Remaining payments need to be made"
        );

        refundBalance();
        swapStarted = false;

        emit SwapEnded();
    }

    // Terminate the swap by mutual consent of both parties
    function terminateSwap() external onlyStarted {
        require(
            msg.sender == partyA || msg.sender == partyB,
            "Only parties involved can initiate termination"
        );

        if (msg.sender == partyA) {
            partyATerminationConsent = true;
        } else if (msg.sender == partyB) {
            partyBTerminationConsent = true;
        }

        if (partyATerminationConsent && partyBTerminationConsent) {
            refundBalance();
            resetTerminationConsents();
            swapStarted = false;
            emit SwapEnded();
        }
    }

    // Refund balances to the respective parties
    function refundBalance() internal {
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
    }

    // Liquidate the swap if liquidation level is breached
    function liquidateSwap() internal {
        require(
            tokenA.balanceOf(address(this)) < liquidationLevelA ||
                tokenB.balanceOf(address(this)) < liquidationLevelB,
            "None of the parties have reached the liquidation level"
        );

        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));

        if (balanceA < liquidationLevelA) {
            tokenA.transfer(partyB, balanceA);
            emit PartyALiquidated(balanceA);
        }

        if (balanceB < liquidationLevelB) {
            tokenB.transfer(partyA, balanceB);
            emit PartyBLiquidated(balanceB);
        }

        refundBalance();
        swapStarted = false;
    }

    // Helper function to reset swap state
    function resetSwapState() internal {
        swapStarted = false;
        paymentCount = 0;
        partyATerminationConsent = false;
        partyBTerminationConsent = false;
        lastPaymentTime = 0;
        startTime = 0;
        feeA = 0;
        feeB = 0;
        liquidationLevelA = 0;
        liquidationLevelB = 0;
    }

    // Helper function to reset termination consents
    function resetTerminationConsents() internal {
        partyATerminationConsent = false;
        partyBTerminationConsent = false;
    }

    // Process a scheduled payment
    function processPayment() internal {
        tokenA.transfer(partyB, tokenANotional);
        tokenB.transfer(partyA, tokenBNotional);
        lastPaymentTime = block.timestamp;
        paymentCount++;
        emit PaymentMade(tokenANotional, tokenBNotional, lastPaymentTime);
    }

    // Collect fees for swap dealer
    function collectFees() internal {
        tokenA.transfer(owner(), feeA);
        tokenB.transfer(owner(), feeB);
    }
}
