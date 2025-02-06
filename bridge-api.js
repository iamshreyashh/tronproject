const Web3 = require('web3');
const BridgeUSDN = require('./build/contracts/LiquidityPoolTRC20tron.json');
const Bridgetrc = require('./build/contracts/LiquiditypoolTRC20sep.json');

const web3sep = new Web3('https://eth-sepolia.public.blastapi.io');
const web3trc = new Web3('https://api.shasta.trongrid.io');
const adminPrivKeySep = '22ca7ef9b348803c0a7e27549e807d41f1c02777d709d47712af18755c564bba';
const adminPrivKeyTron = 'e954f4c1ad7c7190e2f267d9e827309c44a4146ae7db67fa10c8cacd097d0f42';
const { address: admintron } = web3trc.eth.accounts.wallet.add(admintronPrivKeyTron);
const { address: adminsep } = web3trc.eth.accounts.wallet.add(admintronPrivKeySep);


const bridgeUSDN = new web3sep.eth.Contract(
  BridgeUSDN.abi,
  BridgeUSDN.networks['11155111'].address
);

const bridgeTrc = new web3trc.eth.Contract(
  Bridgetrc.abi,
  Bridgetrc.networks['2'].address
);

// Listen to Transfer event from USDN contract (Ethereum)
bridgeUSDN.events.RecivedUSDN({ fromBlock: 0 })
  .on('data', async (event) => {
    const { to, address, value: amount, nonce } = event.returnValues;
    console.log(`USDN Transfer Event: from ${to}, amount ${amount}`);

    // Trigger action on the TRC (Tron) network after the USDN transfer event
    await handleTRCTransfer(to, amount, nonce);
  })
  .on('error', (error) => {
    console.error('Error in USDN transfer event:', error);
  });

// Listen to Transfer event from TRC contract (Tron)
bridgeTrc.events.RecivedTRC20({ fromBlock: 0 })
  .on('data', async (event) => {
    const { to,address, value: amount, nonce } = event.returnValues;
    console.log(`TRC Transfer Event: from ${to}, amount ${amount}`);

    // Trigger action on the USDN (Ethereum) network after the TRC transfer event
    await handleUSDNTransfer(to, amount, nonce);
  })
  .on('error', (error) => {
    console.error('Error in TRC transfer event:', error);
  });

// Function to handle minting on the TRC network after USDN transfer
async function handleTRCTransfer(to, amount, nonce) {
  const tx = bridgeTrc.methods.transferTRC(to, amount, nonce, "");
  const [gasPrice, gasCost] = await Promise.all([
    web3trc.eth.getGasPrice(),
    tx.estimateGas({ from: admintron }),
  ]);
  
  const data = tx.encodeABI();
  const txData = {
    from: admintron,
    to: bridgeTrc.options.address,
    data,
    gas: gasCost,
    gasPrice
  };

  const receipt = await web3trc.eth.sendTransaction(txData);
  console.log(`TRC Transaction hash: ${receipt.transactionHash}`);
}

// Function to handle minting on the USDN network after TRC transfer
async function handleUSDNTransfer(to, amount, nonce) {
  const tx = bridgeUSDN.methods.transferUSDN(to, amount, nonce);
  const [gasPrice, gasCost] = await Promise.all([
    web3sep.eth.getGasPrice(),
    tx.estimateGas({ from: adminsep }),
  ]);

  const data = tx.encodeABI();
  const txData = {
    from: adminsep,
    to: bridgeUSDN.options.address,
    data,
    gas: gasCost,
    gasPrice
  };

  const receipt = await web3sep.eth.sendTransaction(txData);
  console.log(`USDN Transaction hash: ${receipt.transactionHash}`);
}
