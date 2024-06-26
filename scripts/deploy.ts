import { ethers } from 'hardhat';

async function main() {
    // Get the signer (deployer) address
    const [deployer] = await ethers.getSigners();

    // Deploy the ForwardSwapV1 contract with deployer.address as the constructor parameter
    const ForwardSwapV1 = await ethers.deployContract('ForwardSwapV1', [deployer.address]);

    await ForwardSwapV1.waitForDeployment();

    console.log('ForwardSwapV1 Contract Deployed at ' + ForwardSwapV1.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});