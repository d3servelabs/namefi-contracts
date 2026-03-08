---
name: create2-crosschain-redeploy
description: Redeploy any CREATE2-deployed contract to a new EVM chain, reusing the same deterministic addresses. Use when asked to deploy an existing contract to a new chain, replicate CREATE2 addresses, or cross-chain redeploy.
---

# CREATE2 Cross-Chain Redeployment

Redeploy any CREATE2-deployed contract to a new EVM chain with the same deterministic addresses.

## Prerequisites

- Source chain RPC URL (or Etherscan-compatible API)
- Target chain RPC URL
- Contract address(es) on the source chain
- Access to the deployer key (for actual deployment) or simulation tool (for dry-run)

## Phase 1: Eligibility Check

**Goal:** Confirm the contract was deployed via CREATE2 and identify the factory.

### Step 1.1: Get the creation transaction

```bash
# Use the script or manually query the explorer API
./skills/create2-crosschain-redeploy/scripts/check_create2_eligibility.sh \
  --address <CONTRACT_ADDRESS> \
  --rpc <SOURCE_RPC> \
  --api-url <ETHERSCAN_API_URL> \
  --api-key <ETHERSCAN_API_KEY>
```

Alternatively, look up the contract on the block explorer:
- Etherscan: Contract > More Info > "Contract Creator" shows the creation tx
- The `to` field of the creation tx reveals the factory

### Step 1.2: Identify the CREATE2 factory

Check the creation tx `to` field against known factories:

| Factory | Address | Notes |
|---------|---------|-------|
| Nick's Deterministic Deployer | `0x4e59b44847b379578588920ca78fbf26c0b4956c` | Most common, pre-deployed on all EVM chains |
| CREATE2 Deployer (0age) | `0x0000000000FFe8B47B3e2130213B802212439497` | OpenZeppelin's preferred |
| Arachnid's Deployer | `0x4e59b44847b379578588920ca78fbf26c0b4956c` | Same as Nick's |
| Safe Singleton Factory | `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` | Used by Safe contracts |

See `references/known-factories.md` for full list and behaviors.

### Step 1.3: Handle indirect deployments

**If the creation tx `to` is NOT a known factory** (e.g., it's a Gnosis Safe multisig):

1. The actual factory call is an **internal transaction**
2. Trace the creation tx to find internal calls to the factory:
   ```
   # Etherscan: tx page > "Internal Transactions" tab
   # Or use debug_traceTransaction RPC
   cast run <TX_HASH> --rpc-url <RPC> --trace
   ```
3. Find the internal call where `to` = factory address
4. The `input` data of that internal call contains the salt + initCode

### Step 1.4: Decision gate

- Factory identified? -> Proceed to Phase 2
- No factory found / not CREATE2? -> STOP. Contract uses CREATE (nonce-based) and cannot be redeployed to the same address without controlling the deployer nonce.

## Phase 2: Extract Redeployment Data

**Goal:** Extract the exact calldata needed to reproduce the deployment.

### Step 2.1: Extract salt and initCode from creation tx

For **direct factory calls** (tx `to` = factory):
```bash
./skills/create2-crosschain-redeploy/scripts/extract_create2_calldata.sh \
  --tx-hash <CREATION_TX_HASH> \
  --rpc <SOURCE_RPC>
```

The calldata sent to Nick's deployer is: `salt (32 bytes) || initCode (remaining bytes)`

For **Safe-wrapped transactions**:
```bash
./skills/create2-crosschain-redeploy/scripts/extract_create2_calldata.sh \
  --tx-hash <CREATION_TX_HASH> \
  --rpc <SOURCE_RPC> \
  --trace  # enables internal tx tracing
```

### Step 2.2: Verify the extracted data

Recompute the CREATE2 address and confirm it matches:

```
CREATE2 address = keccak256(0xff ++ factory ++ salt ++ keccak256(initCode))[12:]
```

Using cast:
```bash
# Compute initCodeHash
INIT_CODE_HASH=$(cast keccak <INIT_CODE_HEX>)

# Compute CREATE2 address
cast create2 --starts-with 0x --salt <SALT> --init-code-hash $INIT_CODE_HASH --deployer <FACTORY>
# Or manually: cast compute-create2-address is not a real command, use:
# The script does this automatically
```

### Step 2.3: Check factory availability on target chain

```bash
./skills/create2-crosschain-redeploy/scripts/verify_target_chain.sh \
  --factory <FACTORY_ADDRESS> \
  --rpc <TARGET_RPC>
```

If the factory doesn't exist on the target chain:
- For Nick's deployer: It can be deployed permissionlessly using its pre-signed deployment tx (see `references/known-factories.md`)
- For other factories: Check if a deployment mechanism exists

### Step 2.4: Record the redeployment bundle

For each contract to redeploy, record:
```json
{
  "contract": "<NAME>",
  "factory": "<FACTORY_ADDRESS>",
  "salt": "<0x...32 bytes>",
  "initCode": "<0x...>",
  "expectedAddress": "<0x...>",
  "sourceTxHash": "<0x...>",
  "notes": "any caveats"
}
```

## Phase 3: Handle Initial State & Control

**Goal:** After deploying the raw bytecode, ensure the contract is in the correct state (proxy pointing to right impl, initialized, ownership set).

### Step 3.1: Detect proxy patterns

Check ERC-1967 storage slots to determine if the contract is a proxy:

```bash
# Implementation slot
cast storage <ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <RPC>

# Admin slot
cast storage <ADDRESS> 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url <RPC>

# Beacon slot
cast storage <ADDRESS> 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50 --rpc-url <RPC>
```

See `references/erc1967-slots.md` for slot definitions and interpretation.

### Step 3.2: Map the deployment dependency graph

For a typical TransparentUpgradeableProxy setup:

```
1. Deploy Implementation (logic) contract   -- CREATE2, standalone
2. Deploy ProxyAdmin                         -- CREATE2, constructor takes owner address
3. Deploy TransparentUpgradeableProxy        -- CREATE2, constructor takes (logic, admin, initData)
```

**Important:** The ProxyAdmin is often created as a **child contract** inside the TransparentUpgradeableProxy constructor (in newer OZ versions). In older versions, it's deployed separately.

Check which pattern applies:
- If ProxyAdmin was deployed via separate CREATE2 tx -> deploy it first
- If ProxyAdmin was created inside proxy constructor -> it will be recreated automatically

### Step 3.3: Plan post-deployment setup

After redeploying the proxy with its original initCode:
1. The proxy points to the **original** implementation from when it was first deployed
2. If the source chain has been upgraded since, you need to upgrade on the target chain too
3. Identify the current implementation on source chain:
   ```bash
   cast storage <PROXY_ADDRESS> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <SOURCE_RPC>
   ```
4. Deploy the current implementation to target chain (same CREATE2 or new deployment)
5. Call `ProxyAdmin.upgrade(proxy, newImpl)` or `ProxyAdmin.upgradeAndCall(proxy, newImpl, data)`

### Step 3.4: Identify required keys

Map out which private keys / multisigs are needed:

| Action | Required Key |
|--------|-------------|
| Send CREATE2 deployment txs | Any funded account (factory is permissionless) |
| Call ProxyAdmin.upgrade() | ProxyAdmin owner |
| Call initialize() on proxy | **Anyone** (once) — **caller receives DEFAULT_ADMIN_ROLE + MINTER_ROLE** |
| Grant roles post-deploy | Contract admin / DEFAULT_ADMIN_ROLE holder |

**Critical:** `initialize()` is NOT called during proxy deployment (proxy constructor has empty `data`). It must be called explicitly as a separate TX. The `msg.sender` of that call becomes the contract admin. Call it from the intended admin address.

**Testnet pattern — ProxyAdmin ownership hand-off:**
If the ProxyAdmin owner key is not the same as the testnet operator key, add a `transferOwnership` step immediately after ProxyAdmin deployment:

```bash
# op.d3serve.eth (original owner) hands off to Tester Admin
cast send <PROXY_ADMIN_ADDRESS> \
  "transferOwnership(address)" <TESTER_ADMIN_ADDRESS> \
  --rpc-url <TARGET_RPC> \
  --private-key <OP_OWNER_KEY>
```

After this, Tester Admin can call `upgrade()` and all subsequent txs use a single key.

### Step 3.5: Simulate with Hardhat Fork

Before executing on-chain, simulate the full sequence using Hardhat's network forking. This is the recommended approach — it runs the actual EVM against a live fork of the target chain, with account impersonation so you don't need private keys.

**Configure Hardhat to fork the target chain** (`hardhat.config.ts`):
```ts
networks: {
  hardhat: {
    forking: {
      url: "<TARGET_RPC_URL>",
    },
    chainId: <TARGET_CHAIN_ID>,
  },
}
```

**Write a simulation script** (`scripts/simulate-deploy.ts`):
```ts
import { ethers, network } from "hardhat";

async function impersonate(address: string) {
  await network.provider.request({ method: "hardhat_impersonateAccount", params: [address] });
  await network.provider.send("hardhat_setBalance", [address, "0x56BC75E2D63100000"]); // 100 ETH
  return ethers.getSigner(address);
}

async function main() {
  const deployer = await impersonate("<DEPLOYER_ADDRESS>");
  const admin    = await impersonate("<PROXYADMIN_OWNER_ADDRESS>");

  // Step 1: Deploy contracts via CREATE2
  await deployer.sendTransaction({ to: NICK_DEPLOYER, data: "<salt+initCode>", gasLimit: 6_000_000 });

  // Step 2: Upgrade (from ProxyAdmin owner)
  const upgradeData = new ethers.utils.Interface(["function upgrade(address,address)"])
    .encodeFunctionData("upgrade", [PROXY, NEW_IMPL]);
  await admin.sendTransaction({ to: PROXY_ADMIN, data: upgradeData });

  // Step 3: Initialize (msg.sender becomes admin — call from intended admin account)
  await deployer.sendTransaction({ to: PROXY, data: "0x8129fc1c" }); // initialize()

  // Verify post-state
  const implSlot = await ethers.provider.getStorageAt(PROXY, ERC1967_IMPL_SLOT);
  console.assert(implSlot.includes(NEW_IMPL.slice(2).toLowerCase()), "impl mismatch");

  const nft = new ethers.Contract(PROXY, ["function ownerOf(uint256) view returns (address)"], ethers.provider);
  // ... additional assertions
}
```

**Run the simulation** (no real txs sent):
```bash
npx hardhat run scripts/simulate-deploy.ts --network hardhat
```

**Key advantages over `eth_call`:**
- Stateful — each step sees the state from previous steps
- Account impersonation — no private keys needed
- Full EVM trace — real revert messages if something fails
- Can verify post-state (storage slots, role membership, ownership)

**See `scripts/simulate-robinhood-deploy.ts` in this repo** for a complete worked example simulating the full NamefiNFT deployment sequence on Robinhood testnet.

## Checklist

Before executing deployment:

- [ ] All CREATE2 factories exist on target chain
- [ ] All salt + initCode pairs verified (recomputed addresses match)
- [ ] Deployment order respects dependencies (impl before proxy)
- [ ] `initialize()` must be called separately (proxy constructor has empty data) — **caller gets DEFAULT_ADMIN_ROLE**
- [ ] Post-deployment upgrade path planned (if proxy was upgraded on source)
- [ ] Required keys identified and available
- [ ] Hardhat fork simulation passes all assertions
- [ ] Target chain gas token funded in deployer account

## Troubleshooting

### "Factory not found on target chain"
Deploy Nick's factory using its pre-signed tx. See `references/known-factories.md`.

### "CREATE2 address mismatch"
- Ensure you're using the exact same initCode (same compiler version, same constructor args)
- Verify the salt is correct (full 32 bytes, not truncated)
- Confirm the factory address matches

### "ProxyAdmin owner mismatch"
The ProxyAdmin owner is set in the constructor. If the original owner key isn't available on the target chain, you'll need to either:
1. Use the same EOA/multisig address (deploy Safe to same address first if needed)
2. Accept a different owner and plan for ownership transfer

### "Contract already initialized"
If re-initializing after upgrade, ensure the initializer hasn't already been called. Use `initializer` modifier or version-guarded `reinitializer(n)`.
