/**
 * deploy-robinhood-testnet.ts
 *
 * Real deployment of NamefiNFT to Robinhood Chain Testnet (chain ID 46630).
 * Sends actual transactions signed by the deployer account from MNEMONIC.
 *
 * Environment variables:
 *   MNEMONIC: BIP39 seed phrase (required)
 *   ROBINHOOD_TESTNET_RPC_URL: RPC endpoint (defaults to public testnet RPC)
 *   TARGET_ADMIN: Address to grant admin roles to (defaults to namefidao.eth)
 *   CONFIRMATIONS: Number of blocks to wait before confirming (defaults to 2)
 *
 * Run:
 *   source .env && ./node_modules/.bin/hardhat run --network robinhood_testnet scripts/deploy-robinhood-testnet.ts
 *
 * Note: MNEMONIC must derive op.d3serve.eth (0x01bf7f...) at index 0,
 *       because it is the ProxyAdmin owner hardcoded in the CREATE2 initcode.
 */

import { ethers, network } from "hardhat";
import { readFileSync } from "fs";
import path from "path";

const NICK_DEPLOYER = "0x4e59b44847b379578588920ca78fbf26c0b4956c";
const PROXY_ADMIN = "0x00000000009209F45C2822E3f11b7a73014130F1";
const PROXY = "0x0000000000cf80E7Cf8Fa4480907f692177f8e06";
const IMPL_ORIG = "0x00000000f34FA72595f0B1FA90718Cdd865D6d44";
const IMPL_V140 = "0x00008eea299efc29d7bdafec0465feaa828064fa";
const MULTICALL3 = "0xcA11bde05977b3631167028862bE2a173976CA11";

const DEFAULT_ADMIN_ROLE =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const MINTER_ROLE =
  "0xf0887ba65ee2024ea881d91b74c2450ef19e1557f03bed3ea9f16b037cbe2dc9";

// Known addresses
const OP_D3SERVE = "0x01bf7f00540988622a32de1089b7dea09a867188"; // op.d3serve.eth — ProxyAdmin owner (hardcoded in CREATE2 initcode)
const NAMEFIDAO = "0x1b0f291c8fFebE891886351CDfF8A304a840C8Ad"; // namefidao.eth — Tester Admin
const MAINNET_ADMIN = "0xEe15C2735eD48C80f50fe666b45fE9ec699daEE5"; // Mainnet NamefiNFT admin

const NFT_IFACE = new ethers.utils.Interface([
  "function initialize()",
  "function grantRole(bytes32 role, address account)",
  "function revokeRole(bytes32 role, address account)",
  "function hasRole(bytes32 role, address account) view returns (bool)",
  "function name() view returns (string)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function tokenURI(uint256 tokenId) view returns (string)",
]);

const MC3_IFACE = new ethers.utils.Interface([
  "function aggregate3(tuple(address target, bool allowFailure, bytes callData)[] calls) payable returns (tuple(bool success, bytes returnData)[])",
]);

const PROXY_ADMIN_IFACE = new ethers.utils.Interface([
  "function owner() view returns (address)",
  "function transferOwnership(address newOwner)",
]);

async function sendTx(
  signer: any,
  to: string,
  data: string,
  label: string,
  gasPrice: import("ethers").BigNumber,
  confirmations: number = 2
) {
  console.log(`\n  → ${label}`);
  const signerAddr = await signer.getAddress();
  console.log(`    From: ${signerAddr}`);
  console.log(`    To: ${to}`);

  const tx = await signer.sendTransaction({
    to,
    data,
    gasLimit: 8_000_000,
    gasPrice,
  });
  console.log(`    TX Hash: ${tx.hash}`);

  const receipt = await tx.wait(confirmations);
  if (!receipt) throw new Error(`Failed to get receipt for ${label}`);

  console.log(`    Block: ${receipt.blockNumber}`);
  console.log(`    Gas Used: ${receipt.gasUsed.toString()}`);

  if (receipt.status === 0) {
    throw new Error(
      `TRANSACTION REVERTED: ${label}. Please check the error logs.`
    );
  }

  return receipt;
}

async function verifyContractDeployed(address: string, label: string) {
  const code = await ethers.provider.getCode(address);
  const isDeployed = code.length > 2;
  console.log(`    ${label}: ${isDeployed ? "✓ YES" : "✗ NO"} at ${address}`);
  if (!isDeployed) {
    throw new Error(`Contract not deployed at ${address}`);
  }
  return isDeployed;
}

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  const networkUrl = (network.config as any).url || "in-process hardhat node";
  const gasPrice = await ethers.provider.getGasPrice();
  console.log(`\n${"=".repeat(70)}`);
  console.log("NamefiNFT Robinhood Testnet Deployment");
  console.log(`Network: ${network.name}`);
  console.log(`Chain ID: ${chainId}`);
  console.log(`RPC: ${networkUrl}`);
  console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, "gwei")} gwei`);
  console.log(`${"=".repeat(70)}`);

  if (network.name !== "robinhood_testnet") {
    throw new Error(
      `Wrong network! Expected "robinhood_testnet", got "${network.name}". ` +
      `Use: hardhat run --network robinhood_testnet scripts/deploy-robinhood-testnet.ts`
    );
  }

  if (chainId !== 46630) {
    throw new Error(
      `Wrong chain ID! Expected 46630, got ${chainId}. Check robinhood_testnet config.`
    );
  }

  // Load deployment calldata
  const deployTxJson = JSON.parse(
    readFileSync(path.join(__dirname, "../docs/robinhood-testnet-deploy-tx.json"), "utf8")
  );

  // Get signer
  const signer = ethers.provider.getSigner(0);
  const signerAddr = await signer.getAddress();
  const balance = await ethers.provider.getBalance(signerAddr);
  const balanceEth = ethers.utils.formatEther(balance);

  console.log(`\nDeployer Address: ${signerAddr}`);

  // Verify signer is op.d3serve.eth (required for ProxyAdmin.upgrade in step 1e)
  if (signerAddr.toLowerCase() !== OP_D3SERVE.toLowerCase()) {
    throw new Error(
      `Signer mismatch! Expected op.d3serve.eth (${OP_D3SERVE}), got ${signerAddr}. ` +
      `The deployer must be op.d3serve.eth because it is the ProxyAdmin owner (hardcoded in CREATE2 initcode).`
    );
  }
  console.log(`✓ Signer is op.d3serve.eth (ProxyAdmin owner)`);

  console.log(`Balance: ${balanceEth} ETH`);

  // Estimate required balance: ~9M gas total with 50% buffer
  const ESTIMATED_TOTAL_GAS = 9_000_000;
  const requiredBalance = gasPrice.mul(ESTIMATED_TOTAL_GAS).mul(150).div(100);
  const requiredEth = ethers.utils.formatEther(requiredBalance);
  console.log(`Estimated cost (with 50% buffer): ${requiredEth} ETH`);

  if (balance.lt(requiredBalance)) {
    throw new Error(
      `Insufficient balance! Need at least ${requiredEth} ETH for gas, have ${balanceEth}`
    );
  }

  const TARGET_ADMIN = process.env.TARGET_ADMIN || NAMEFIDAO;
  const CONFIRMATIONS = parseInt(process.env.CONFIRMATIONS || "2");

  console.log(`Target Admin: ${TARGET_ADMIN}`);
  console.log(`Confirmations: ${CONFIRMATIONS}`);

  // ── TX1: Deploy all contracts + upgrade + initialize ──────────────
  console.log(`\n${"─".repeat(70)}`);
  console.log("[TX1] Deploy + Upgrade + Initialize");
  console.log(`${"─".repeat(70)}`);

  // 1a: Deploy original impl
  const step1a = deployTxJson.steps[0];
  await sendTx(signer, NICK_DEPLOYER, step1a.data, "1a: Deploy NamefiNFT original impl", gasPrice, CONFIRMATIONS);
  await verifyContractDeployed(IMPL_ORIG, "IMPL_ORIG");

  // 1b: Deploy ProxyAdmin
  const step1b = deployTxJson.steps[1];
  await sendTx(signer, NICK_DEPLOYER, step1b.data, "1b: Deploy ProxyAdmin", gasPrice, CONFIRMATIONS);
  await verifyContractDeployed(PROXY_ADMIN, "PROXY_ADMIN");

  // Note: No ownership transfer needed — op.d3serve.eth is already the
  // ProxyAdmin owner (hardcoded in CREATE2 initcode).

  // 1c: Deploy NFT Proxy
  const step1c = deployTxJson.steps[2];
  await sendTx(signer, NICK_DEPLOYER, step1c.data, "1c: Deploy NamefiNFT Proxy", gasPrice, CONFIRMATIONS);
  await verifyContractDeployed(PROXY, "PROXY");

  // 1d: Deploy v1.4.0 impl
  const step1d = deployTxJson.steps[3];
  await sendTx(signer, NICK_DEPLOYER, step1d.data, "1d: Deploy NamefiNFT v1.4.0 impl", gasPrice, CONFIRMATIONS);
  await verifyContractDeployed(IMPL_V140, "IMPL_V140");

  // 1e: Upgrade proxy to v1.4.0
  const step1e = deployTxJson.steps[4];
  await sendTx(
    signer,
    PROXY_ADMIN,
    step1e.data,
    "1e: Upgrade proxy to v1.4.0",
    gasPrice,
    CONFIRMATIONS
  );

  // Verify impl slot
  const implSlot = await ethers.provider.getStorageAt(
    PROXY,
    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
  );
  const implAddr =
    "0x" + implSlot.slice(-40).toLowerCase();
  console.log(
    `    Implementation slot: ${implAddr}`
  );
  if (implAddr.toLowerCase() !== IMPL_V140.toLowerCase()) {
    throw new Error(`Impl slot mismatch! Expected ${IMPL_V140}, got ${implAddr}`);
  }
  console.log(`    ✓ Impl slot correct`);

  // 1f: Multicall3 — initialize + grant to TARGET_ADMIN & MAINNET_ADMIN + revoke from Multicall3 (atomic)
  const mc3Calldata = MC3_IFACE.encodeFunctionData("aggregate3", [
    [
      {
        target: PROXY,
        allowFailure: false,
        callData: NFT_IFACE.encodeFunctionData("initialize"),
      },
      {
        target: PROXY,
        allowFailure: false,
        callData: NFT_IFACE.encodeFunctionData("grantRole", [
          DEFAULT_ADMIN_ROLE,
          TARGET_ADMIN,
        ]),
      },
      {
        target: PROXY,
        allowFailure: false,
        callData: NFT_IFACE.encodeFunctionData("grantRole", [
          MINTER_ROLE,
          TARGET_ADMIN,
        ]),
      },
      {
        target: PROXY,
        allowFailure: false,
        callData: NFT_IFACE.encodeFunctionData("grantRole", [
          DEFAULT_ADMIN_ROLE,
          MAINNET_ADMIN,
        ]),
      },
      {
        target: PROXY,
        allowFailure: false,
        callData: NFT_IFACE.encodeFunctionData("grantRole", [
          MINTER_ROLE,
          MAINNET_ADMIN,
        ]),
      },
      // Grant deployer (op.d3serve.eth) both roles so it can manage roles & mint in TX2
      {
        target: PROXY,
        allowFailure: false,
        callData: NFT_IFACE.encodeFunctionData("grantRole", [
          DEFAULT_ADMIN_ROLE,
          OP_D3SERVE,
        ]),
      },
      {
        target: PROXY,
        allowFailure: false,
        callData: NFT_IFACE.encodeFunctionData("grantRole", [
          MINTER_ROLE,
          OP_D3SERVE,
        ]),
      },
      {
        target: PROXY,
        allowFailure: false,
        callData: NFT_IFACE.encodeFunctionData("revokeRole", [
          MINTER_ROLE,
          MULTICALL3,
        ]),
      },
      {
        target: PROXY,
        allowFailure: false,
        callData: NFT_IFACE.encodeFunctionData("revokeRole", [
          DEFAULT_ADMIN_ROLE,
          MULTICALL3,
        ]),
      },
    ],
  ]);
  await sendTx(
    signer,
    MULTICALL3,
    mc3Calldata,
    "1f: Multicall3 — init + grant TARGET_ADMIN + revoke Multicall3 (atomic)",
    gasPrice,
    CONFIRMATIONS
  );

  // ── TX1 Post-State Verification ───────────────────────────────────
  console.log(`\n${"─".repeat(70)}`);
  console.log("[TX1 Post-State Verification]");
  console.log(`${"─".repeat(70)}`);

  const adminSlot = await ethers.provider.getStorageAt(
    PROXY,
    "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
  );
  const adminAddr =
    "0x" + adminSlot.slice(-40).toLowerCase();
  console.log(`  Admin slot: ${adminAddr}`);
  if (adminAddr.toLowerCase() !== PROXY_ADMIN.toLowerCase()) {
    throw new Error(
      `Admin slot mismatch! Expected ${PROXY_ADMIN}, got ${adminAddr}`
    );
  }
  console.log(`  ✓ Admin slot correct`);

  // Check ProxyAdmin owner
  const proxyAdminOwner = await ethers.provider.call({
    to: PROXY_ADMIN,
    data: PROXY_ADMIN_IFACE.encodeFunctionData("owner"),
  });
  const proxyAdminOwnerAddr = PROXY_ADMIN_IFACE.decodeFunctionResult(
    "owner",
    proxyAdminOwner
  )[0];
  console.log(`  ProxyAdmin owner: ${proxyAdminOwnerAddr}`);
  if (
    proxyAdminOwnerAddr.toLowerCase() !== TARGET_ADMIN.toLowerCase()
  ) {
    console.log(
      `  ⚠ ProxyAdmin owner is not TARGET_ADMIN (ownership may need manual transfer)`
    );
  } else {
    console.log(`  ✓ ProxyAdmin owner is TARGET_ADMIN`);
  }

  // Check TARGET_ADMIN roles
  const hasAdmin = await ethers.provider.call({
    to: PROXY,
    data: NFT_IFACE.encodeFunctionData("hasRole", [
      DEFAULT_ADMIN_ROLE,
      TARGET_ADMIN,
    ]),
  });
  const hasAdminBool =
    NFT_IFACE.decodeFunctionResult("hasRole", hasAdmin)[0];
  console.log(
    `  TARGET_ADMIN has DEFAULT_ADMIN_ROLE: ${hasAdminBool ? "✓ YES" : "✗ NO"}`
  );

  const hasMinter = await ethers.provider.call({
    to: PROXY,
    data: NFT_IFACE.encodeFunctionData("hasRole", [MINTER_ROLE, TARGET_ADMIN]),
  });
  const hasMinterBool =
    NFT_IFACE.decodeFunctionResult("hasRole", hasMinter)[0];
  console.log(
    `  TARGET_ADMIN has MINTER_ROLE: ${hasMinterBool ? "✓ YES" : "✗ NO"}`
  );

  // Check Multicall3 roles revoked
  const mc3HasAdmin = await ethers.provider.call({
    to: PROXY,
    data: NFT_IFACE.encodeFunctionData("hasRole", [
      DEFAULT_ADMIN_ROLE,
      MULTICALL3,
    ]),
  });
  const mc3HasAdminBool =
    NFT_IFACE.decodeFunctionResult("hasRole", mc3HasAdmin)[0];
  console.log(
    `  Multicall3 has DEFAULT_ADMIN_ROLE: ${!mc3HasAdminBool ? "✓ REVOKED" : "✗ STILL HAS"}`
  );

  const mc3HasMinter = await ethers.provider.call({
    to: PROXY,
    data: NFT_IFACE.encodeFunctionData("hasRole", [MINTER_ROLE, MULTICALL3]),
  });
  const mc3HasMinterBool =
    NFT_IFACE.decodeFunctionResult("hasRole", mc3HasMinter)[0];
  console.log(
    `  Multicall3 has MINTER_ROLE: ${!mc3HasMinterBool ? "✓ REVOKED" : "✗ STILL HAS"}`
  );

  // Check deployer (op.d3serve.eth) roles
  const deployerHasAdmin = await ethers.provider.call({
    to: PROXY,
    data: NFT_IFACE.encodeFunctionData("hasRole", [DEFAULT_ADMIN_ROLE, OP_D3SERVE]),
  });
  const deployerHasAdminBool =
    NFT_IFACE.decodeFunctionResult("hasRole", deployerHasAdmin)[0];
  console.log(
    `  op.d3serve.eth has DEFAULT_ADMIN_ROLE: ${deployerHasAdminBool ? "✓ YES" : "✗ NO"}`
  );

  const deployerHasMinter = await ethers.provider.call({
    to: PROXY,
    data: NFT_IFACE.encodeFunctionData("hasRole", [MINTER_ROLE, OP_D3SERVE]),
  });
  const deployerHasMinterBool =
    NFT_IFACE.decodeFunctionResult("hasRole", deployerHasMinter)[0];
  console.log(
    `  op.d3serve.eth has MINTER_ROLE: ${deployerHasMinterBool ? "✓ YES" : "✗ NO"}`
  );

  if (!hasAdminBool || !hasMinterBool || !deployerHasAdminBool || !deployerHasMinterBool || mc3HasAdminBool || mc3HasMinterBool) {
    throw new Error("TX1 post-state verification failed!");
  }

  // ── TX2: Mint example.com ────────────────────────────────────────
  console.log(`\n${"─".repeat(70)}`);
  console.log("[TX2] Mint 'example.com' NFT");
  console.log(`${"─".repeat(70)}`);

  const mintCalldata = NFT_IFACE.encodeFunctionData(
    "safeMintByNameNoCharge",
    ["example.com"]
  );
  await sendTx(
    signer,
    PROXY,
    mintCalldata,
    "TX2: safeMintByNameNoCharge('example.com')",
    gasPrice,
    CONFIRMATIONS
  );

  // ── TX2 Post-State Verification ───────────────────────────────────
  console.log(`\n${"─".repeat(70)}`);
  console.log("[TX2 Post-State Verification]");
  console.log(`${"─".repeat(70)}`);

  // Get token ID for 'example.com'
  const domainHash = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("example.com")
  );
  const tokenId = ethers.BigNumber.from(domainHash);
  console.log(`  Domain: example.com`);
  console.log(`  Token ID: ${tokenId.toString()}`);

  // Check owner
  const owner = await ethers.provider.call({
    to: PROXY,
    data: NFT_IFACE.encodeFunctionData("ownerOf", [tokenId]),
  });
  const ownerAddr =
    NFT_IFACE.decodeFunctionResult("ownerOf", owner)[0];
  console.log(`  Owner: ${ownerAddr}`);
  if (ownerAddr.toLowerCase() !== signerAddr.toLowerCase()) {
    console.log(
      `  ⚠ Token owner is ${ownerAddr}, not the signer (${signerAddr})`
    );
  } else {
    console.log(`  ✓ Owner is signer`);
  }

  // ── Summary ───────────────────────────────────────────────────────
  console.log(`\n${"=".repeat(70)}`);
  console.log("✓ DEPLOYMENT COMPLETE");
  console.log(`${"=".repeat(70)}`);
  console.log(`\nKey Contracts:`);
  console.log(`  NamefiNFT Proxy:       ${PROXY}`);
  console.log(`  NamefiNFT Impl v1.4.0: ${IMPL_V140}`);
  console.log(`  ProxyAdmin:            ${PROXY_ADMIN}`);
  console.log(`  Nick's Deployer:       ${NICK_DEPLOYER}`);
  console.log(`\nAdministration:`);
  console.log(`  TARGET_ADMIN:          ${TARGET_ADMIN}`);
  console.log(`  Minter:                ${TARGET_ADMIN}`);
  console.log(`\nExplorer:`);
  console.log(`  https://blockscout.robinhood.com/address/${PROXY}`);
  console.log(`\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n✗ DEPLOYMENT FAILED");
    console.error(error.message || error);
    process.exit(1);
  });
