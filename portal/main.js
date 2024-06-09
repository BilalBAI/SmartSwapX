// main.js

import Web3 from 'web3';
import { contractABI, contractAddress } from './contract.js';

// Initialize web3
let web3;
if (window.ethereum) {
    web3 = new Web3(window.ethereum);
    try {
        window.ethereum.enable(); // Request account access
    } catch (error) {
        console.error("User denied account access");
    }
} else if (window.web3) {
    web3 = new Web3(window.web3.currentProvider);
} else {
    console.log('Non-Ethereum browser detected. You should consider trying MetaMask!');
}

const contract = new web3.eth.Contract(contractABI, contractAddress);

// Function to fetch and display all existing contracts
async function fetchContracts() {
    const contractsList = document.getElementById('contracts-list');
    contractsList.innerHTML = '';

    const otherContractsList = document.getElementById('other-contracts-list');
    otherContractsList.innerHTML = '';

    const totalContracts = await contract.methods.totalContracts().call();
    for (let i = 0; i < totalContracts; i++) {
        const contractInfo = await contract.methods.contracts(i).call();
        const div = document.createElement('div');
        div.className = 'contract';
        div.innerHTML = `
            <h3>Contract ${i}</h3>
            <p>Party A: ${contractInfo.partyA}</p>
            <p>Party B: ${contractInfo.partyB}</p>
            <p>ETH Notional: ${contractInfo.ethNotional}</p>
            <p>USDC Notional: ${contractInfo.usdcNotional}</p>
            <p>ETH Rate: ${contractInfo.ethRate}%</p>
            <p>USDC Rate: ${contractInfo.usdcRate}%</p>
            <p>Payment Interval: ${contractInfo.paymentInterval}s</p>
            <p>Total Duration: ${contractInfo.totalDuration}s</p>
        `;
        if (contractInfo.ethNotional > 0 && contractInfo.usdcNotional > 0) {
            contractsList.appendChild(div);
        } else {
            otherContractsList.appendChild(div);
        }
    }
}

// Function to handle contract creation
document.getElementById('create-contract-form').addEventListener('submit', async (e) => {
    e.preventDefault();

    const partyA = document.getElementById('partyA').value;
    const partyB = document.getElementById('partyB').value;
    const ethNotional = document.getElementById('ethNotional').value;
    const usdcNotional = document.getElementById('usdcNotional').value;
    const ethRate = document.getElementById('ethRate').value;
    const usdcRate = document.getElementById('usdcRate').value;
    const paymentInterval = document.getElementById('paymentInterval').value;
    const totalDuration = document.getElementById('totalDuration').value;
    const ethMargin = document.getElementById('ethMargin').value;
    const usdcMargin = document.getElementById('usdcMargin').value;

    const accounts = await web3.eth.getAccounts();

    await contract.methods.createContract(
        partyA,
        partyB,
        ethNotional,
        usdcNotional,
        ethRate,
        usdcRate,
        paymentInterval,
        totalDuration,
        ethMargin,
        usdcMargin
    ).send({ from: accounts[0] });

    fetchContracts();
});

// Initial fetch of contracts
fetchContracts();
