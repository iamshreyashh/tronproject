const TronWeb = require('tronweb');

// Instantiate TronWeb with a full node, solidity node, and event server
const tronWeb = new TronWeb({
    fullHost: 'https://api.trongrid.io',  // Mainnet or Shasta testnet
});

// Function to convert a Tron address to hex format
function convertTronAddressToHex(tronAddress) {
    try {
        const hexAddress = tronWeb.address.toHex(tronAddress);
        console.log("Hex Address: ", hexAddress);
        return hexAddress;
    } catch (error) {
        console.error("Error converting address: ", error);
    }
}

// Example usage
const tronAddress = "TPZc6B6dT7zwMrW197qYSDg3DvrzoBrrEn"; // Replace with your Tron address
convertTronAddressToHex(tronAddress);
