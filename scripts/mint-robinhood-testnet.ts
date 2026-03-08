/**
 * mint-robinhood-testnet.ts
 *
 * Mints a NamefiNFT domain on Robinhood testnet.
 * Requires MNEMONIC in .env deriving an account with MINTER_ROLE at index 0.
 *
 * Run:
 *   source .env && ./node_modules/.bin/hardhat run --network robinhood_testnet scripts/mint-robinhood-testnet.ts
 */

import { ethers, network } from "hardhat";

const PROXY = "0x0000000000cf80E7Cf8Fa4480907f692177f8e06";

const NFT_IFACE = new ethers.utils.Interface([
  "function safeMintByNameNoCharge(address to, string memory domainName, uint256 expirationTime)",
  "function hasRole(bytes32 role, address account) view returns (bool)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function normalizedDomainNameToId(string memory domainName) pure returns (uint256)",
  "function idToNormalizedDomainName(uint256 tokenId) view returns (string memory)",
]);

const MINTER_ROLE =
  "0xf0887ba65ee2024ea881d91b74c2450ef19e1557f03bed3ea9f16b037cbe2dc9";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const networkUrl = (network.config as any).url || "in-process hardhat node";
  const gasPrice = await ethers.provider.getGasPrice();

  console.log(`\n${"=".repeat(60)}`);
  console.log("NamefiNFT Mint — Robinhood Testnet");
  console.log(`Network: ${network.name} | Chain ID: ${chainId}`);
  console.log(`RPC: ${networkUrl}`);
  console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, "gwei")} gwei`);
  console.log(`${"=".repeat(60)}`);

  if (network.name !== "robinhood_testnet") {
    throw new Error(
      `Wrong network! Expected "robinhood_testnet", got "${network.name}". ` +
      `Use: hardhat run --network robinhood_testnet scripts/mint-robinhood-testnet.ts`
    );
  }

  const signer = ethers.provider.getSigner(0);
  const signerAddr = await signer.getAddress();
  const balance = await ethers.provider.getBalance(signerAddr);
  console.log(`\nMinter: ${signerAddr}`);
  console.log(`Balance: ${ethers.utils.formatEther(balance)} ETH`);

  // Verify signer has MINTER_ROLE
  const hasMinter = await ethers.provider.call({
    to: PROXY,
    data: NFT_IFACE.encodeFunctionData("hasRole", [MINTER_ROLE, signerAddr]),
  });
  const hasMinterBool = NFT_IFACE.decodeFunctionResult("hasRole", hasMinter)[0];
  if (!hasMinterBool) {
    throw new Error(`Signer ${signerAddr} does not have MINTER_ROLE on ${PROXY}`);
  }
  console.log(`✓ Signer has MINTER_ROLE`);

  // Mint
  const domainName = "example.com";
  const expiry = 1893456000; // 2030-01-01
  const mintTo = signerAddr;

  console.log(`\nMinting "${domainName}" to ${mintTo} (expires ${new Date(expiry * 1000).toISOString()})`);

  const mintCalldata = NFT_IFACE.encodeFunctionData("safeMintByNameNoCharge", [
    mintTo, domainName, expiry,
  ]);

  const tx = await signer.sendTransaction({
    to: PROXY,
    data: mintCalldata,
    gasLimit: 500_000,
    gasPrice,
  });
  console.log(`TX Hash: ${tx.hash}`);

  const receipt = await tx.wait(2);
  if (receipt.status === 0) throw new Error("Mint transaction reverted!");
  console.log(`Block: ${receipt.blockNumber}`);
  console.log(`Gas Used: ${receipt.gasUsed.toString()}`);

  // Verify
  const nft = new ethers.Contract(PROXY, NFT_IFACE, ethers.provider);
  const tokenId = await nft.normalizedDomainNameToId(domainName);
  const owner = await nft.ownerOf(tokenId);
  const name = await nft.idToNormalizedDomainName(tokenId);

  console.log(`\n${"─".repeat(60)}`);
  console.log(`Token ID: ${tokenId.toString()}`);
  console.log(`Domain:   ${name}`);
  console.log(`Owner:    ${owner}`);
  console.log(`Match:    ${owner.toLowerCase() === mintTo.toLowerCase() ? "✓ PASS" : "✗ FAIL"}`);
  console.log(`${"=".repeat(60)}`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => { console.error("\n✗ MINT FAILED:", e.message); process.exit(1); });
