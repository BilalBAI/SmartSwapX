# ForwardSwap Smart Contract Explanation for Investors

## Overview
The ForwardSwap smart contract is designed to facilitate token swaps between two parties on a predetermined schedule in the future. This contract is managed by an owner, who acts as the market maker or dealer, facilitating the swap and earning a fee for this service. The contract leverages the security and transparency of blockchain technology to automate and enforce the swap terms.

## Key Features

### Parties Involved
- **Party A**: Holds Token A and wants to receive Token B.
- **Party B**: Holds Token B and wants to receive Token A.

### Tokens and Notionals
- **Token A and Token B**: ERC-20 tokens to be exchanged.
- **Notional Amounts**: Specified amounts of Token A and Token B to be exchanged in each payment cycle.

### Swap Details
- **Payment Interval**: The time period between each scheduled payment.
- **Total Duration**: The overall duration for which the swap is active.

### Margins and Fees
- **Initial and Maintenance Margins**: Required deposits to ensure parties can meet their obligations.
- **Market Maker Fee**: A fee in basis points (bps) paid to the dealer for each payment.

### Swap Lifecycle
- **Setting Up**: The owner sets up the swap parameters, including tokens, notional amounts, payment interval, and total duration.
- **Starting the Swap**: The swap starts once initial margins are deposited by both parties.
- **Making Payments**: Regular payments are made according to the schedule, transferring the specified token amounts between parties.
- **Ending or Terminating the Swap**: The swap can end after the total duration or be terminated early by mutual consent of both parties.

### Events
- **SwapSet**
- **PartiesSet**
- **SwapMarginAndFeeSet**
- **SwapStarted**
- **MarginDeposited**
- **MarginWithdrawn**
- **PaymentMade**
- **SwapEnded**
- **PartyALiquidated**
- **PartyBLiquidated**

These events log important actions and changes in the contract.

## Detailed Functionality

### Setup and Configuration
- **setSwap**: Allows the owner to set the swap parameters, including tokens, notionals, payment interval, and total duration.
- **setParties**: Assigns Party A and Party B addresses.
- **setMarginFee**: Configures the initial and maintenance margins as well as the market maker fee.

### Margin Management
- **depositMarginTokenA/TokenB**: Parties can deposit their respective token margins.
- **withdrawMarginTokenA/TokenB**: Parties can withdraw their margins before the swap starts.

### Swap Execution
- **startSwap**: Initiates the swap, requiring sufficient initial margins from both parties.
- **makePayment**: Facilitates scheduled payments, ensuring maintenance margins are maintained and liquidating positions if necessary.

### Swap Termination
- **endSwap**: Ends the swap after the total duration.
- **terminateSwap**: Allows either party to propose termination, requiring consent from both parties to execute.

### Maintenance and Liquidation
- **liquidateSwap**: Liquidates the swap if maintenance margins are breached.
- **refundBalance**: Ensures all remaining balances are refunded to the respective parties at the end of the swap or upon termination.

### Fee Collection
- **collectFees**: Collects the dealer's fee from each payment, transferring it to the contract owner.

## Conclusion
The ForwardSwap contract offers a structured and automated way for two parties to exchange token flows over a set period, providing security through margin requirements and ensuring fair facilitation via dealer fees. It’s a robust mechanism leveraging blockchain's transparency and immutability, aimed at providing a reliable tool for forward token swaps.
