import { task } from "hardhat/config";
import { ethers } from "ethers";
// Setup: npm install alchemy-sdk
import { Alchemy, Network } from "alchemy-sdk";
import fs from 'fs';
import path from 'path';
import * as dotenv from "dotenv";

dotenv.config();

task("get-mint-txs", "Get latest mint transactions for an ERC-20 token")
  .addParam("address", "The ERC-20 token contract address")
  .setAction(async (taskArgs, hre) => {
 
  const config = {
    apiKey: process.env.ALCHEMY_API_KEY,
    network: Network.ETH_MAINNET,
  };
  const alchemy = new Alchemy(config);
  
  const contractAddresses = "0x0000000000c39A0F674c12A5e63eb8031B550b6f";
  
  const res = await alchemy.core.getAssetTransfers({
    fromBlock: "0x0",
    fromAddress: "0x0000000000000000000000000000000000000000",
    contractAddresses: [contractAddresses],
    category: ["erc20"] as any,
  });

  const erc20HashToTx = new Map();
  res.transfers.forEach((tx:any) => {
    erc20HashToTx.set(tx.hash, tx);
  });

  // Fetch transaction details for each hash
  const paymentTxes = (await Promise.all(res.transfers.map(async (tx) => {
    const hash = tx.hash;
    try {
      const tx = await alchemy.core.getTransaction(hash);
      return tx;
    } catch (error) {
      console.error(`Error fetching transaction ${hash}:`, error);
      return null;
    }
  }))).filter(tx => {
    return tx && tx.value && ethers.BigNumber.from(tx.value).gt(ethers.BigNumber.from(0));
  });


  // Create CSV content
  let csvContent = "Transaction DateTime, Payer Address,Transaction Hash,Ethers Paid,ERC-20 Tokens Received\n";

  for (let i = 0; i < paymentTxes.length; i++) {
    const tx = paymentTxes[i]!;
    const erc20Tx = erc20HashToTx.get(tx.hash);
    
    const payerAddress = tx.from;
    const txHash = tx.hash;
    const ethersPaid = ethers.utils.formatEther(tx.value);
    const tokensReceived = erc20Tx.value;
    const block = await alchemy.core.getBlock(tx.blockNumber!);
    const blockTime = new Date(block.timestamp * 1000).toISOString();

    csvContent += `${blockTime},https://etherscan.io/address/${payerAddress},https://etherscan.io/tx/${txHash},${ethersPaid},${tokensReceived}\n`;
  }

  // Create output directory if it doesn't exist

  const outputDir = path.join(__dirname, '..', 'output');
  
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  fs.writeFileSync('output/nfsc-payments.csv', csvContent);
});
