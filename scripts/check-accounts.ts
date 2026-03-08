import { ethers } from "hardhat";

async function main() {
  console.log("\n=== Account Check ===\n");
  console.log(`RPC: ${ethers.provider.connection?.url}\n`);

  for (let i = 0; i < 5; i++) {
    const signer = ethers.provider.getSigner(i);
    const addr = await signer.getAddress();
    const balance = await ethers.provider.getBalance(addr);
    const balEth = ethers.utils.formatEther(balance);
    const match = addr.toLowerCase() === "0x1b0f291c8ffebe891886351cdff8a304a840c8ad" ? " ← TARGET" : "";
    console.log(`[${i}] ${addr} | ${balEth} ETH${match}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.error(e);
    process.exit(1);
  });
