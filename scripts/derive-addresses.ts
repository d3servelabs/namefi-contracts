import { ethers } from "ethers";

async function main() {
  const mnemonic = process.env.MNEMONIC;
  
  if (!mnemonic) {
    console.error("Error: MNEMONIC env var not set");
    process.exit(1);
  }

  console.log("\n=== Deriving Addresses from Mnemonic ===\n");
  
  const hdNode = ethers.utils.HDNode.fromMnemonic(mnemonic);
  const target = "0x1b0f291c8ffebe891886351cdff8a304a840c8ad";
  
  console.log("Derived accounts from mnemonic:\n");
  
  for (let i = 0; i < 20; i++) {
    const path = `m/44'/60'/0'/0/${i}`;
    const childNode = hdNode.derivePath(path);
    const addr = childNode.address;
    const match = addr.toLowerCase() === target.toLowerCase() ? " ← TARGET FOUND!" : "";
    console.log(`[${i}]  ${addr}${match}`);
  }
}

main();
