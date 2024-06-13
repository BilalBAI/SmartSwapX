// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ForwardSwap is Ownable {
    /*
        A forward swap enables parties to exchange token flows 
        according to a predetermined schedule in the future.
        Owner of this contract is the forward swap dealer/market maker
        that helps to facilitate the process and thus is entitled to a fee. 
        If there is no active dealer involved, the dealer fee can be set to zero.
    */

    // Swap parties and tokens
    address public partyA; // Party holding token A and wanting to receive token B
    address public partyB; // Party holding token B and wanting to receive token A
    IERC20 public tokenA; // ERC-20 token A address
    IERC20 public tokenB; // ERC-20 token B address

    // Swap details
    uint256 public tokenANotional; // Amount of token A to be transferred to party B in each payment
    uint256 public tokenBNotional; // Amount of token B to be transferred to party A in each payment
    uint256 public paymentInterval; // Payment interval in seconds
    uint256 public totalPaymentCount; // Total number of swap payments
    // uint256 public totalDuration; // Total swap duration in seconds

    // Margin and fees
    uint256 public initMarginBps; // Initial Margin in base points of notional
    uint256 public maintenanceMarginBps; // Maintenance Margin in base points of notional
    uint256 public marketMakerFeeBps; // Market maker/dealer fee in basis points for each payment

    // Swap state variables
    uint256 public paymentCount; // the number of payments has been made
    uint256 public lastPaymentTime; // Last payment timestamp
    uint256 public startTime; // Swap start timestamp
    bool public swapStarted; // Flag indicating if the swap has started
    bool public partyATerminationConsent; // Party A's termination consent
    bool public partyBTerminationConsent; // Party B's termination consent

    // Events
    event SwapSet();
    event PartiesSet(address indexed partyA, address indexed partyB);
    event SwapMarginAndFeeSet(
        uint256 initMarginBps,
        uint256 MaintenanceMarginBps,
        uint256 marketMakerFeeBps
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

    // Set swap parameters
    function setSwap(
        address _tokenA,
        address _tokenB,
        uint256 _tokenANotional,
        uint256 _tokenBNotional,
        uint256 _paymentInterval,
        uint256 _totalPaymentCount
    ) external onlyOwner {
        require(!swapStarted, "Cannot reset swap, the swap has started");
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
    function setParties(address _partyA, address _partyB) external onlyOwner {
        require(!swapStarted, "Cannot reset swap, the swap has started");
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
        uint256 _initMarginBps,
        uint256 _maintenanceMarginBps,
        uint256 _marketMakerFeeBps
    ) external onlyOwner {
        require(!swapStarted, "Cannot reset swap, the swap has started");
        refundBalance();

        initMarginBps = _initMarginBps;
        maintenanceMarginBps = _maintenanceMarginBps;
        marketMakerFeeBps = _marketMakerFeeBps;

        emit SwapMarginAndFeeSet(
            initMarginBps,
            maintenanceMarginBps,
            marketMakerFeeBps
        );
    }

    // Start the swap
    function startSwap() external onlyOwner {
        uint256 tokenAInitMargin = (tokenANotional * initMarginBps) / 10000;
        uint256 tokenBInitMargin = (tokenBNotional * initMarginBps) / 10000;

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

    // Withdraw margin for Token A
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

        emit MarginWithdrawn(partyA);
    }

    // Deposit margin for Token B
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

    // Withdraw margin for Token B
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

        emit MarginWithdrawn(partyB);
    }

    // Make a scheduled payment
    function makePayment() external {
        require(swapStarted, "Swap has not started");
        require(
            block.timestamp >= lastPaymentTime + paymentInterval,
            "Payment interval has not passed"
        );
        require(
            paymentCount < totalPaymentCount,
            "All payments have been made"
        );
        // Calculate Maintenance Margin
        uint256 tokenAMaintenanceMargin = (tokenANotional *
            maintenanceMarginBps) / 10000;
        uint256 tokenBMaintenanceMargin = (tokenBNotional *
            maintenanceMarginBps) / 10000;
        // Calculate Dealer Fee
        uint256 feeA = (tokenANotional * marketMakerFeeBps) / 10000;
        uint256 feeB = (tokenBNotional * marketMakerFeeBps) / 10000;
        // Calculate liquidationLevel: Need to have sufficient balance
        // to cover MaintenanceMargin + fee + Notional for this payment
        uint256 liquidationLevelA = tokenAMaintenanceMargin +
            tokenANotional +
            feeA;
        uint256 liquidationLevelB = tokenBMaintenanceMargin +
            tokenBNotional +
            feeB;

        collectFees(feeA, feeB);

        if (
            tokenA.balanceOf(address(this)) < liquidationLevelA ||
            tokenB.balanceOf(address(this)) < liquidationLevelB
        ) {
            liquidateSwap(liquidationLevelA, liquidationLevelB);
        } else {
            processPayment();
            paymentCount++;
        }
    }

    // End the swap after the total duration has passed
    function endSwap() external {
        require(swapStarted, "Swap has not started");
        require(
            paymentCount >= totalPaymentCount,
            "Remaining payments need to be made"
        );

        refundBalance();
        swapStarted = false;

        emit SwapEnded();
    }

    // Terminate the swap by mutual consent of both parties
    function terminateSwap() external {
        require(
            msg.sender == partyA || msg.sender == partyB,
            "Only parties involved can initiate termination"
        );
        require(swapStarted, "Swap has not started");

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

    // Liquidate the swap if maintenance margin is breached
    function liquidateSwap(
        uint256 liquidationLevelA,
        uint256 liquidationLevelB
    ) internal {
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
            tokenB.transfer(partyA, balanceB / 2);
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
        emit PaymentMade(tokenANotional, tokenBNotional, lastPaymentTime);
    }

    // Collect fees for swap dealer
    function collectFees(uint256 feeA, uint256 feeB) internal {
        tokenA.transfer(owner(), feeA);
        tokenB.transfer(owner(), feeB);
    }
}
