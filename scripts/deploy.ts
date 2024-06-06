import { ethers } from 'hardhat';

async function main() {
    const FFCurrencySwap = await ethers.deployContract('FFCurrencySwap');

    await FFCurrencySwap.waitForDeployment();

    console.log('FFCurrencySwap Contract Deployed at ' + FFCurrencySwap.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});