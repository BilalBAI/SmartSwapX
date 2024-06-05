import { ethers } from 'hardhat';

async function main() {
    const FFCSErc20Erc20 = await ethers.deployContract('FFCSErc20Erc20');

    await FFCSErc20Erc20.waitForDeployment();

    console.log('FFCSErc20Erc20 Contract Deployed at ' + FFCSErc20Erc20.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});