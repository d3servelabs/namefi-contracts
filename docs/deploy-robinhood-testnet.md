# NamefiNFT Deployment to Robinhood Testnet

## Overview

Deploy NamefiNFT (and related infrastructure) to Robinhood Chain Testnet by replaying the same CREATE2 deployment transactions used on Ethereum mainnet. This produces identical contract addresses across chains.

## Network Details

| Property | Value |
|----------|-------|
| Chain Name | Robinhood Chain Testnet |
| Chain ID | 46630 |
| RPC URL | `https://rpc.testnet.chain.robinhood.com` |
| RPC (Alchemy) | `https://robinhood-testnet.g.alchemy.com/v2/<API_KEY>` |
| Block Explorer | `https://explorer.testnet.chain.robinhood.com` |
| Native Token | ETH |
| Faucet | `https://faucet.testnet.chain.robinhood.com` |
| Architecture | Arbitrum Orbit L2 on Ethereum |

## Ethereum Deployment Reference

### Contract Addresses (deterministic via CREATE2)

| Contract | Address | Ethereum Creation TX |
|----------|---------|---------------------|
| ProxyAdmin | `0x00000000009209F45C2822E3f11b7a73014130F1` | [`0x2eef69e1...`](https://etherscan.io/tx/0x2eef69e1f4a707c977521a8d79ace40b49f00724e2ed6fcbb8d5b6ee86f6d550) |
| NamefiNFT Proxy | `0x0000000000cf80E7Cf8Fa4480907f692177f8e06` | [`0x3f62692e...`](https://etherscan.io/tx/0x3f62692e8c0f6940280925c9982572110bd0dfc893a5d03284c9ad3548b7b83a) |
| NamefiNFT Impl (original) | `0x00000000f34FA72595f0B1FA90718Cdd865D6d44` | [`0x12dd6f80...`](https://etherscan.io/tx/0x12dd6f80c37b863bbf07c42fb3ed61cf1ae9c0c23d8a40e65d568be9131de6c9) |
| NamefiNFT Impl (v1.4.0-rc1) | `0x00008eea299efc29d7bdafec0465feaa828064fa` | [`0x8c1bae2b...`](https://etherscan.io/tx/0x8c1bae2b4532e658e5f60f4fcd9ee4ca213130d71e5c2562bb5ebdf7ed3a1c16) |

### CREATE2 Salts (Nonces)

| Contract | Salt |
|----------|------|
| ProxyAdmin | `0x00000000000000000000000000000000000000005715a2bbff5b843d84e1daf8` |
| NamefiNFT Impl (original) | `0x0000000000000000000000000000000000000000de26213fdd792730e8a811cb` |
| NamefiNFT Proxy | `0x0000000000000000000000000000000000000000ebf9c231fad1d33999ec0da2` |
| NamefiNFT Impl (v1.4.0-rc1) | `0x19e9cc052fb15e8191ebd19f59d8c1c2574b45beeb5a2b7f81a37acc38da04eb` |

### Key Addresses

| Role | Address |
|------|---------|
| ProxyAdmin Owner | `0x01Bf7f00540988622a32de1089B7DeA09a867188` |
| Current Implementation | `0x00008eea299efc29d7bdafec0465feaa828064fa` (v1.4.0-rc1) |
| CREATE2 Factory (Nick's) | `0x4e59b44847b379578588920ca78fbf26c0b4956c` |

## Prerequisites

1. **Funded account** on Robinhood testnet (get ETH from faucet)
2. **MNEMONIC** set in `.env`
3. **Network config** added to `hardhat.config.ts` (already done in this branch)

### Verify Nick's Deployer Exists

```bash
cast code 0x4e59b44847b379578588920ca78fbf26c0b4956c --rpc-url https://rpc.testnet.chain.robinhood.com
# Should return: 0x7fffffff...f3 (not 0x)
```

**Status: VERIFIED** - Nick's deployer exists on Robinhood testnet.

## Deployment Steps

### Step 1: Deploy the Original NamefiNFT Implementation

This deploys the original logic contract that the proxy was first initialized with.

```bash
npx hardhat namefi-nick-deploy-logic \
  --network robinhood_testnet \
  --logic-contract-name NamefiNFT \
  --nonce 0x0000000000000000000000000000000000000000de26213fdd792730e8a811cb \
  --dry-run
```

**IMPORTANT:** You must compile with the exact same Solidity version and source code that was used for the original Ethereum deployment. The initCode must match byte-for-byte.

Expected address: `0x00000000f34FA72595f0B1FA90718Cdd865D6d44`

After verifying the dry-run output, remove `--dry-run` to execute.

### Step 2: Deploy ProxyAdmin

```bash
npx hardhat namefi-nick-deploy-proxy-admin \
  --network robinhood_testnet \
  --nonce 0x00000000000000000000000000000000000000005715a2bbff5b843d84e1daf8
```

Expected address: `0x00000000009209F45C2822E3f11b7a73014130F1`

The ProxyAdmin constructor sets its owner to `0x01Bf7f00540988622a32de1089B7DeA09a867188`. This address must exist and be controlled on Robinhood testnet to perform upgrades.

### Step 3: Deploy NamefiNFT Proxy

```bash
npx hardhat namefi-nick-deploy-proxy \
  --network robinhood_testnet \
  --logic-contract-name NamefiNFT \
  --logic-address 0x00000000f34FA72595f0B1FA90718Cdd865D6d44 \
  --admin-address 0x00000000009209F45C2822E3f11b7a73014130F1 \
  --nonce 0x0000000000000000000000000000000000000000ebf9c231fad1d33999ec0da2
```

Expected address: `0x0000000000cf80E7Cf8Fa4480907f692177f8e06`

This will:
1. Deploy the TransparentUpgradeableProxy
2. Point it to the original impl at `0x00000000f34FA72595f0B1FA90718Cdd865D6d44`
3. Set admin to `0x00000000009209F45C2822E3f11b7a73014130F1`
4. Call `initialize()` on the proxy

### Step 4: Deploy v1.4.0-rc1 Implementation

**Caveat:** On Ethereum, this tx was sent through a Safe multisig (`0xFafa4243Ec016187E03388d70B7c5819616C44D5`). For Robinhood testnet, send directly to Nick's deployer.

Option A — Using hardhat task:
```bash
npx hardhat namefi-nick-deploy-logic \
  --network robinhood_testnet \
  --logic-contract-name NamefiNFT \
  --nonce 0x19e9cc052fb15e8191ebd19f59d8c1c2574b45beeb5a2b7f81a37acc38da04eb
```

Option B — Using manual calldata:
```bash
npx hardhat namefi-manual-deploy \
  --contract NamefiNFT \
  --nonce 0x19e9cc052fb15e8191ebd19f59d8c1c2574b45beeb5a2b7f81a37acc38da04eb
```

Then send the generated calldata to Nick's deployer (`0x4e59b44847b379578588920ca78fbf26c0b4956c`).

**IMPORTANT:** Must compile from the same git commit and Solidity version used for the Ethereum deployment. Otherwise the initCode will differ and the CREATE2 address won't match.

Expected address: `0x00008eea299efc29d7bdafec0465feaa828064fa`

### Step 5: Upgrade Proxy to v1.4.0-rc1

The ProxyAdmin owner (`0x01Bf7f00540988622a32de1089B7DeA09a867188`) must call:

```bash
npx hardhat namefi-upgrade \
  --network robinhood_testnet \
  --proxy-address 0x0000000000cf80E7Cf8Fa4480907f692177f8e06 \
  --logic-address 0x00008eea299efc29d7bdafec0465feaa828064fa
```

Or manually via the ProxyAdmin contract:
```bash
cast send 0x00000000009209F45C2822E3f11b7a73014130F1 \
  "upgrade(address,address)" \
  0x0000000000cf80E7Cf8Fa4480907f692177f8e06 \
  0x00008eea299efc29d7bdafec0465feaa828064fa \
  --rpc-url https://rpc.testnet.chain.robinhood.com \
  --private-key <PROXY_ADMIN_OWNER_KEY>
```

### Step 6: Verify Deployment

```bash
# Check implementation slot points to v1.4.0-rc1
cast storage 0x0000000000cf80E7Cf8Fa4480907f692177f8e06 \
  0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc \
  --rpc-url https://rpc.testnet.chain.robinhood.com
# Expected: 0x00000000000000000000000000008eea299efc29d7bdafec0465feaa828064fa

# Check admin slot
cast storage 0x0000000000cf80E7Cf8Fa4480907f692177f8e06 \
  0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 \
  --rpc-url https://rpc.testnet.chain.robinhood.com
# Expected: 0x00000000000000000000000000000000009209f45c2822e3f11b7a73014130f1

# Check ProxyAdmin owner
cast call 0x00000000009209F45C2822E3f11b7a73014130F1 \
  "owner()(address)" \
  --rpc-url https://rpc.testnet.chain.robinhood.com
# Expected: 0x01Bf7f00540988622a32de1089B7DeA09a867188
```

### Step 7: Verify Source Code on Explorer

```bash
npx hardhat verify \
  --network robinhood_testnet \
  --contract contracts/NamefiNFT.sol:NamefiNFT \
  0x00008eea299efc29d7bdafec0465feaa828064fa

npx hardhat verify \
  --network robinhood_testnet \
  --contract contracts/NamefiProxyAdmin.sol:NamefiProxyAdmin \
  0x00000000009209F45C2822E3f11b7a73014130F1 \
  0x01Bf7f00540988622a32de1089B7DeA09a867188
```

## Deployment Order Summary

```
1. NamefiNFT Impl (original)  -> 0x00000000f34FA72595f0B1FA90718Cdd865D6d44
2. ProxyAdmin                  -> 0x00000000009209F45C2822E3f11b7a73014130F1
3. NamefiNFT Proxy             -> 0x0000000000cf80E7Cf8Fa4480907f692177f8e06
   (proxy constructor has empty data — initialize() NOT called here)
4. NamefiNFT Impl (v1.4.0)    -> 0x00008eea299efc29d7bdafec0465feaa828064fa
5. Upgrade proxy to v1.4.0     (ProxyAdmin.upgrade, from op.d3serve.eth)
6. initialize()                (from namefidao.eth — grants them DEFAULT_ADMIN_ROLE + MINTER_ROLE)
7. Verify + post-deploy setup
```

## Simulation

Before executing on-chain, run the full sequence locally against a Hardhat fork:

```bash
npx hardhat run scripts/simulate-robinhood-deploy.ts --network hardhat
```

This forks Robinhood testnet, impersonates the required accounts, executes all TXs in sequence, and verifies post-state (impl slot, admin slot, roles, and a test mint of `example.com`). All steps must show `✓ PASS` before proceeding with real deployment.

## Caveats

### Safe-Wrapped Implementation TX

The v1.4.0-rc1 implementation deployment on Ethereum (`0x8c1bae2b...`) was sent through a Gnosis Safe multisig at `0xFafa4243Ec016187E03388d70B7c5819616C44D5`. The actual CREATE2 factory call happens as an internal transaction. On Robinhood testnet, send directly to Nick's deployer — the CREATE2 address is determined only by (factory, salt, initCode), not by the caller.

### ProxyAdmin Owner

The ProxyAdmin owner is hardcoded in the constructor as `0x01Bf7f00540988622a32de1089B7DeA09a867188`. Ensure this address is funded and accessible on Robinhood testnet. If using a different admin, the ProxyAdmin address will differ (since the constructor arg is part of initCode).

### Compiler Version Matching

All contracts must be compiled with **Solidity 0.8.24** with optimizer enabled (200 runs) to produce matching initCode. The `hardhat.config.ts` already specifies this.

### Git Commit for v1.4.0-rc1

The v1.4.0-rc1 implementation must be compiled from the exact source code used on Ethereum. If the contract source has changed since, check out the correct commit before compiling and deploying Step 4.
