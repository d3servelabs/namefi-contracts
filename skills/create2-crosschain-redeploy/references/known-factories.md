# Known CREATE2 Factory Contracts

## Nick's Deterministic Deployment Proxy

- **Address:** `0x4e59b44847b379578588920ca78fbf26c0b4956c`
- **Also known as:** Arachnid's Deterministic Deployer, Nick Johnson's Deployer
- **Deployed on:** Virtually all EVM chains (pre-deployed via keyless deployment)
- **Source:** https://github.com/Arachnid/deterministic-deployment-proxy

### Behavior

- **Input format:** `salt (32 bytes) || initCode (N bytes)` — sent as raw tx data
- **Output:** Deploys the contract at `CREATE2(factory, salt, keccak256(initCode))`
- **No ABI:** Not a standard contract call; the entire calldata is salt + initCode
- **Permissionless:** Anyone can call it
- **No constructor args encoding:** Constructor args are appended to the bytecode in `initCode`

### Address Computation

```
address = keccak256(0xff ++ 0x4e59b44847b379578588920ca78fbf26c0b4956c ++ salt ++ keccak256(initCode))[12:]
```

### Deploying the Factory Itself

If the factory doesn't exist on a target chain, it can be deployed using a pre-signed transaction:

```bash
# 1. Fund the deployer address with gas money
# Deployer EOA: 0x3fab184622dc19b6109349b94811493bf2a45362
cast send 0x3fab184622dc19b6109349b94811493bf2a45362 --value 0.01ether --rpc-url <TARGET_RPC>

# 2. Broadcast the pre-signed deployment transaction
cast publish --rpc-url <TARGET_RPC> 0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378163019160015760005250602081019050f01625a0440c05dd3940e8abba6abaf3a2cd7f3bec7a80a5b6a2a2fac1e3ac5f20e1e0f5a0636c3e6f55c3b6cb20cf5c2e00b5015d3e76b69cd0d86b8b4d98fa51dcc53bec
```

### Verification

After deploying:
```bash
cast code 0x4e59b44847b379578588920ca78fbf26c0b4956c --rpc-url <TARGET_RPC>
# Should return: 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378163019160015760005250602081019050f0
```

## 0age's CREATE2 Deployer (Immutable Create2 Factory)

- **Address:** `0x0000000000FFe8B47B3e2130213B802212439497`
- **Used by:** Some OpenZeppelin tooling, various projects

### Behavior

- **Input format:** Standard ABI-encoded call: `safeCreate2(bytes32 salt, bytes initCode)`
- **Function selector:** `0x85cf97ab`
- **Has ABI:** Yes, standard Solidity contract
- **Extra feature:** Prevents deployment to addresses that already have code

## Safe Singleton Factory

- **Address:** `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7`
- **Used by:** Safe (Gnosis Safe) contracts
- **Source:** https://github.com/safe-global/safe-singleton-factory

### Behavior

- **Input format:** ABI-encoded: `deploy(bytes initCode, bytes32 salt)`
- **Function selector:** `0x64e03087`

## Identifying Which Factory Was Used

1. Look at the creation tx `to` field
2. If `to` matches a known factory address above -> direct call
3. If `to` is a multisig/proxy (e.g., Safe):
   - Check internal transactions for calls to factory addresses
   - The internal call's `input` contains the factory-specific calldata
4. If `to` is `null` (contract creation tx):
   - This is a regular CREATE deployment, NOT CREATE2
   - Cannot replicate address on another chain via CREATE2

## Chain-Specific Notes

### Chains where Nick's deployer is pre-deployed
Virtually all EVM-compatible chains including: Ethereum, Polygon, Arbitrum, Optimism, Base, BSC, Avalanche, Fantom, Gnosis, and most testnets.

### Chains that may need manual deployment
Some newer or custom chains may not have the deployer. Check with:
```bash
cast code 0x4e59b44847b379578588920ca78fbf26c0b4956c --rpc-url <TARGET_RPC>
```
If result is `0x`, deploy using the pre-signed tx above.
