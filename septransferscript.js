const { ethers } = require("ethers");

// Replace with your deployed contract address and ABI
const CONTRACT_ADDRESS = "0x66DBEEDa3c62c7ad50061B655353f566b63722d1";
const CONTRACT_ABI = [{
    "constant": false,
    "inputs": [
      {
        "internalType": "address",
        "name": "recipient",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "transfer",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
  
];

// Replace with your Ethereum provider URL
const PROVIDER_URL = "https://eth-sepolia.public.blastapi.io";

// Replace with the sender's private key
const PRIVATE_KEY = "22ca7ef9b348803c0a7e27549e807d41f1c02777d709d47712af18755c564bba";

async function transferTokens(recipient, amount) {
  try {
    // Set up the provider and wallet
    const provider = new ethers.JsonRpcProvider(PROVIDER_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    // Instantiate the contract
    const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);

    // Convert amount to the correct decimals (assume 18 decimals for this example)
    const amountInWei = ethers.parseUnits(amount.toString(), 18);

    console.log(`Initiating transfer of ${amount} tokens to ${recipient}...`);

    // Call the transfer function
    const tx = await contract.transfer(recipient, amountInWei);

    console.log("Transaction submitted. Waiting for confirmation...");
    await tx.wait();

    console.log(`Transaction confirmed! Hash: ${tx.hash}`);
  } catch (error) {
    console.error("Error during token transfer:", error);
  }
}

// Example usage
const recipientAddress = "RECIPIENT_ADDRESS_HERE";
const tokenAmount = 100; // Replace with the number of tokens to transfer
transferTokens(recipientAddress, tokenAmount);
