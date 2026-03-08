import { ethers } from "hardhat";

const OP_D3SERVE = "0x01bf7f00540988622a32de1089b7dea09a867188";

async function main() {
  const gasPrice = await ethers.provider.getGasPrice();
  const gasPriceGwei = ethers.utils.formatUnits(gasPrice, "gwei");
  console.log(`Gas Price: ${gasPriceGwei} gwei`);

  // Gas used from simulation
  const steps: [string, number][] = [
    ["1a: Deploy original impl", 3723153],
    ["1b: Deploy ProxyAdmin", 446521],
    ["1c: Deploy NFT Proxy", 600792],
    ["1d: Deploy v1.4.0 impl", 3812296],
    ["1e: Upgrade proxy", 38998],
    ["1f: Multicall3 init+roles", 213256],
    ["TX2: Mint example.com", 134305],
  ];

  let totalGas = 0;
  console.log(`\n${"Step".padEnd(30)} ${"Gas Used".padStart(10)}    Cost (ETH)`);
  console.log("-".repeat(65));
  for (const [step, gas] of steps) {
    totalGas += gas;
    const cost = gasPrice.mul(gas);
    console.log(`${step.padEnd(30)} ${gas.toString().padStart(10)}    ${ethers.utils.formatEther(cost)}`);
  }
  console.log("-".repeat(65));
  const totalCost = gasPrice.mul(totalGas);
  console.log(`${"TOTAL".padEnd(30)} ${totalGas.toString().padStart(10)}    ${ethers.utils.formatEther(totalCost)}`);
  console.log(`\nEstimated cost: ${ethers.utils.formatEther(totalCost)} ETH`);
  console.log(`With 50% buffer: ${ethers.utils.formatEther(totalCost.mul(150).div(100))} ETH`);

  // Check op.d3serve.eth balance
  const balance = await ethers.provider.getBalance(OP_D3SERVE);
  console.log(`\nop.d3serve.eth balance: ${ethers.utils.formatEther(balance)} ETH`);

  const deficit = totalCost.mul(150).div(100).sub(balance);
  if (deficit.gt(0)) {
    console.log(`Shortfall: ${ethers.utils.formatEther(deficit)} ETH — need to fund op.d3serve.eth`);
  } else {
    console.log(`✓ Sufficient balance`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((e) => { console.error(e); process.exit(1); });
