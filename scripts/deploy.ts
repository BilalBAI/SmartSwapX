import { ethers } from 'hardhat';

async function main() {
    const ForwardSwap = await ethers.deployContract('ForwardSwap');

    await ForwardSwap.waitForDeployment();

    console.log('ForwardSwap Contract Deployed at ' + ForwardSwap.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});