// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ForwardSwapV1.sol"; // Ensure the ForwardSwapV1 contract is in the same directory

contract SwapFactory is Ownable {
    // Event emitted when a new ForwardSwapV1 contract is created
    event SwapCreated(address swapAddress, address owner);

    // Array to keep track of all created swap contracts
    address[] public allSwaps;

    // Constructor to set the owner
    constructor() Ownable(msg.sender) {}

    // Function to create a new ForwardSwapV1 contract
    function createSwap() external onlyOwner returns (address) {
        // Create a new ForwardSwapV1 contract
        ForwardSwapV1 newSwap = new ForwardSwapV1(msg.sender);

        // Store the address of the new swap contract
        allSwaps.push(address(newSwap));

        // Emit an event
        emit SwapCreated(address(newSwap), msg.sender);

        // Return the address of the new swap contract
        return address(newSwap);
    }

    // Function to get all created swap contracts
    function getAllSwaps() external view returns (address[] memory) {
        return allSwaps;
    }
}
