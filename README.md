# SmartSwapX
SmartSwapX is a novel implementation of a customizable forward swap using smart contracts.

### Introduction
[Smart Swap Introduction](SmartSwapXIntro.md)

### Deployed Version on Base Sepolia
[ForwardSwapV1](https://sepolia.basescan.org/address/0xffa78261a2a6f6f780473abcd9a331bf3cc58a3b)

<!-- https://docs.base.org/tutorials/deploy-with-hardhat -->

### Install
#### Install Dependencies
```bash
npm install --save-dev hardhat
npm install --save-dev @nomicfoundation/hardhat-toolbox
npm install --save-dev dotenv
npm install --save @openzeppelin/contracts
```

#### .env
```bash
WALLET_KEY="<YOUR_PRIVATE_KEY>"
BASESCAN_API_KEY="<YOUR_API_KEY>"
```

#### Compile, deploy and verify
```bash
npx hardhat compile
npx hardhat run scripts/deploy.ts --network base-sepolia
npx hardhat verify --network base-sepolia <deployed address>
```
