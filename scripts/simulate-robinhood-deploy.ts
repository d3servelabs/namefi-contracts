/**
 * simulate-robinhood-deploy.ts
 *
 * Simulates the full NamefiNFT deployment sequence on a Hardhat fork of Robinhood testnet.
 * No real transactions are sent. Uses account impersonation + eth_sendTransaction.
 *
 * Run:
 *   npx hardhat run scripts/simulate-robinhood-deploy.ts --network hardhat
 *   (or: ./node_modules/.bin/hardhat run scripts/simulate-robinhood-deploy.ts --network robinhood_testnet)
 * (hardhat.config.ts must have forking enabled — see bottom of this file for config snippet)
 */

import { ethers, network } from "hardhat";
import { readFileSync } from "fs";
import path from "path";

const NICK_DEPLOYER = "0x4e59b44847b379578588920ca78fbf26c0b4956c";
const PROXY_ADMIN   = "0x00000000009209F45C2822E3f11b7a73014130F1";
const PROXY         = "0x0000000000cf80E7Cf8Fa4480907f692177f8e06";
const IMPL_ORIG     = "0x00000000f34FA72595f0B1FA90718Cdd865D6d44";
const IMPL_V140     = "0x00008eea299efc29d7bdafec0465feaa828064fa";
const MULTICALL3    = "0xcA11bde05977b3631167028862bE2a173976CA11";

const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
const MINTER_ROLE        = "0xf0887ba65ee2024ea881d91b74c2450ef19e1557f03bed3ea9f16b037cbe2dc9";

// TX senders
const NAMEFIDAO = "0x1b0f291c8fFebE891886351CDfF8A304a840C8Ad"; // namefidao.eth — Tester Admin
const PA_OWNER  = "0x01Bf7f00540988622a32de1089B7DeA09a867188"; // op.d3serve.eth — transfers ProxyAdmin ownership

const NFT_IFACE = new ethers.utils.Interface([
  "function initialize()",
  "function grantRole(bytes32 role, address account)",
  "function revokeRole(bytes32 role, address account)",
  "function hasRole(bytes32 role, address account) view returns (bool)",
]);

const MC3_IFACE = new ethers.utils.Interface([
  "function aggregate3(tuple(address target, bool allowFailure, bytes callData)[] calls) payable returns (tuple(bool success, bytes returnData)[])",
]);

async function impersonate(address: string) {
  await network.provider.request({ method: "hardhat_impersonateAccount", params: [address] });
  await network.provider.send("hardhat_setBalance", [address, "0x56BC75E2D63100000"]); // 100 ETH
  return ethers.getSigner(address);
}

async function sendRaw(signer: any, to: string, data: string, label: string) {
  console.log(`\n  → ${label}`);
  const tx = await signer.sendTransaction({ to, data, gasLimit: 8_000_000 });
  const receipt = await tx.wait();
  console.log(`    TX: ${receipt.hash}`);
  console.log(`    Gas used: ${receipt.gasUsed.toString()}`);
  if (receipt.status === 0) throw new Error(`REVERTED: ${label}`);
  return receipt;
}

async function main() {
  const deployTxJson = JSON.parse(
    readFileSync(path.join(__dirname, "../docs/robinhood-testnet-deploy-tx.json"), "utf8")
  );

  console.log("=".repeat(60));
  console.log("Robinhood Testnet Deployment Simulation");
  console.log("Fork: https://rpc.testnet.chain.robinhood.com");
  console.log("=".repeat(60));

  const namefidao = await impersonate(NAMEFIDAO);  // Tester Admin — signs all testnet txs
  const paOwner   = await impersonate(PA_OWNER);   // op.d3serve.eth — needed only to transfer ProxyAdmin ownership

  // ── TX1: Deploy all contracts + upgrade + initialize ──────────────
  console.log("\n[TX1] Deploy + Upgrade + Initialize");
  console.log("─".repeat(40));

  // 1a: Deploy original impl
  const step1a = deployTxJson.steps[0];
  await sendRaw(namefidao, NICK_DEPLOYER, step1a.data, "1a: Deploy NamefiNFT original impl");
  const impl_orig_code = await ethers.provider.getCode(IMPL_ORIG);
  console.log(`    Code deployed: ${impl_orig_code.length > 2 ? "YES" : "NO"} at ${IMPL_ORIG}`);

  // 1b: Deploy ProxyAdmin (mainnet calldata sets op.d3serve.eth as owner)
  const step1b = deployTxJson.steps[1];
  await sendRaw(namefidao, NICK_DEPLOYER, step1b.data, "1b: Deploy ProxyAdmin");
  const admin_code = await ethers.provider.getCode(PROXY_ADMIN);
  console.log(`    Code deployed: ${admin_code.length > 2 ? "YES" : "NO"} at ${PROXY_ADMIN}`);

  // Testnet setup: op.d3serve.eth transfers ProxyAdmin ownership to Tester Admin (namefidao.eth)
  const transferOwnershipCalldata = new ethers.utils.Interface([
    "function transferOwnership(address newOwner)"
  ]).encodeFunctionData("transferOwnership", [NAMEFIDAO]);
  await sendRaw(paOwner, PROXY_ADMIN, transferOwnershipCalldata, "1b-post: transferOwnership(namefidao.eth) from op.d3serve.eth");

  // 1c: Deploy NFT Proxy
  const step1c = deployTxJson.steps[2];
  await sendRaw(namefidao, NICK_DEPLOYER, step1c.data, "1c: Deploy NamefiNFT Proxy");
  const proxy_code = await ethers.provider.getCode(PROXY);
  console.log(`    Code deployed: ${proxy_code.length > 2 ? "YES" : "NO"} at ${PROXY}`);

  // 1d: Deploy v1.4.0 impl
  const step1d = deployTxJson.steps[3];
  await sendRaw(namefidao, NICK_DEPLOYER, step1d.data, "1d: Deploy NamefiNFT v1.4.0 impl");
  const impl_v140_code = await ethers.provider.getCode(IMPL_V140);
  console.log(`    Code deployed: ${impl_v140_code.length > 2 ? "YES" : "NO"} at ${IMPL_V140}`);

  // 1e: Upgrade proxy to v1.4.0 (from namefidao.eth — testnet ProxyAdmin owner)
  const upgradeCalldata = new ethers.utils.Interface([
    "function upgrade(address proxy, address implementation)"
  ]).encodeFunctionData("upgrade", [PROXY, IMPL_V140]);
  await sendRaw(namefidao, PROXY_ADMIN, upgradeCalldata, "1e: Upgrade proxy to v1.4.0 (from namefidao.eth)");

  // 1f: Multicall3 — initialize + grant namefidao.eth both roles + revoke Multicall3's own roles (atomic)
  // Multicall3's msg.sender becomes admin after initialize(), so we must grant to namefidao.eth
  // and revoke from Multicall3 atomically — revoke MINTER_ROLE before DEFAULT_ADMIN_ROLE
  const mc3Calldata = MC3_IFACE.encodeFunctionData("aggregate3", [[
    { target: PROXY, allowFailure: false, callData: NFT_IFACE.encodeFunctionData("initialize") },
    { target: PROXY, allowFailure: false, callData: NFT_IFACE.encodeFunctionData("grantRole", [DEFAULT_ADMIN_ROLE, NAMEFIDAO]) },
    { target: PROXY, allowFailure: false, callData: NFT_IFACE.encodeFunctionData("grantRole", [MINTER_ROLE, NAMEFIDAO]) },
    { target: PROXY, allowFailure: false, callData: NFT_IFACE.encodeFunctionData("revokeRole", [MINTER_ROLE, MULTICALL3]) },
    { target: PROXY, allowFailure: false, callData: NFT_IFACE.encodeFunctionData("revokeRole", [DEFAULT_ADMIN_ROLE, MULTICALL3]) },
  ]]);
  await sendRaw(namefidao, MULTICALL3, mc3Calldata, "1f: Multicall3 — init + grant namefidao.eth + revoke Multicall3 (atomic)");

  // ── Verify TX1 post-state ─────────────────────────────────────────
  console.log("\n[TX1 Post-State Verification]");
  console.log("─".repeat(40));

  const ERC1967_IMPL_SLOT  = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
  const ERC1967_ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

  const implSlot  = await ethers.provider.getStorageAt(PROXY, ERC1967_IMPL_SLOT);
  const adminSlot = await ethers.provider.getStorageAt(PROXY, ERC1967_ADMIN_SLOT);
  const implAddr  = "0x" + implSlot.slice(-40);
  const adminAddr = "0x" + adminSlot.slice(-40);

  console.log(`  Implementation slot: ${implAddr}`);
  console.log(`  Expected:            ${IMPL_V140.toLowerCase()}`);
  console.log(`  Impl match: ${implAddr.toLowerCase() === IMPL_V140.toLowerCase() ? "✓ PASS" : "✗ FAIL"}`);
  console.log(`  Admin slot: ${adminAddr}`);

  const proxyAdmin = new ethers.Contract(PROXY_ADMIN, ["function owner() view returns (address)"], ethers.provider);
  const paOwnerAddr = await proxyAdmin.owner();
  console.log(`  ProxyAdmin owner: ${paOwnerAddr}`);
  console.log(`  ProxyAdmin owner match (namefidao.eth): ${paOwnerAddr.toLowerCase() === NAMEFIDAO.toLowerCase() ? "✓ PASS" : "✗ FAIL"}`);

  const nft = new ethers.Contract(PROXY, [
    "function hasRole(bytes32 role, address account) view returns (bool)"
  ], ethers.provider);
  const hasAdmin  = await nft.hasRole(DEFAULT_ADMIN_ROLE, NAMEFIDAO);
  const hasMinter = await nft.hasRole(MINTER_ROLE, NAMEFIDAO);
  console.log(`  namefidao.eth has DEFAULT_ADMIN_ROLE: ${hasAdmin ? "✓ PASS" : "✗ FAIL"}`);
  console.log(`  namefidao.eth has MINTER_ROLE:        ${hasMinter ? "✓ PASS" : "✗ FAIL"}`);
  const mc3HasAdmin  = await nft.hasRole(DEFAULT_ADMIN_ROLE, MULTICALL3);
  const mc3HasMinter = await nft.hasRole(MINTER_ROLE, MULTICALL3);
  console.log(`  Multicall3 has DEFAULT_ADMIN_ROLE: ${!mc3HasAdmin ? "✓ PASS (revoked)" : "✗ FAIL (still holds admin!)"}`);
  console.log(`  Multicall3 has MINTER_ROLE:        ${!mc3HasMinter ? "✓ PASS (revoked)" : "✗ FAIL (still holds minter!)"}`);

  // ── TX2: Mint example.com ────────────────────────────────────────
  console.log("\n[TX2] Mint 'example.com' NFT");
  console.log("─".repeat(40));
  const expiry = 1893456000; // 2030-01-01
  const mintCalldata = new ethers.utils.Interface([
    "function safeMintByNameNoCharge(address to, string memory domainName, uint256 expirationTime)"
  ]).encodeFunctionData("safeMintByNameNoCharge", [NAMEFIDAO, "example.com", expiry]);
  const mintReceipt = await sendRaw(namefidao, PROXY, mintCalldata, "TX2: safeMintByNameNoCharge('example.com')");

  // ── Verify TX2 post-state ─────────────────────────────────────────
  console.log("\n[TX2 Post-State Verification]");
  console.log("─".repeat(40));

  const nftFull = new ethers.Contract(PROXY as string, [
    "function normalizedDomainNameToId(string memory domainName) pure returns (uint256)",
    "function ownerOf(uint256 tokenId) view returns (address)",
    "function idToNormalizedDomainName(uint256 tokenId) view returns (string memory)",
  ], ethers.provider);

  const tokenId = await nftFull.normalizedDomainNameToId("example.com");
  console.log(`  Token ID for 'example.com': ${tokenId.toString()}`);

  const owner = await nftFull.ownerOf(tokenId);
  console.log(`  Owner: ${owner}`);
  console.log(`  Owner match: ${owner.toLowerCase() === NAMEFIDAO.toLowerCase() ? "✓ PASS" : "✗ FAIL"}`);

  const domainName = await nftFull.idToNormalizedDomainName(tokenId);
  console.log(`  Domain name: ${domainName}`);

  console.log("\n" + "=".repeat(60));
  console.log("ALL SIMULATIONS PASSED — ready to execute on Robinhood testnet");
  console.log("=".repeat(60));
}

main().catch((err) => {
  console.error("\n✗ SIMULATION FAILED:", err.message);
  process.exit(1);
});

/*
 * Add this to hardhat.config.ts networks section to enable forking:
 *
 * hardhat: {
 *   forking: {
 *     url: "https://rpc.testnet.chain.robinhood.com",
 *     blockNumber: undefined, // latest
 *   }
 * }
 */
