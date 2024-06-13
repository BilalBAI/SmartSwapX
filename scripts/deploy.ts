import { ethers } from 'hardhat';

async function main() {
    const ForwardSwapV1 = await ethers.deployContract('ForwardSwapV1');

    await ForwardSwapV1.waitForDeployment();

    console.log('ForwardSwapV1 Contract Deployed at ' + ForwardSwapV1.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});