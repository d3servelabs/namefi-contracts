# ERC-1967 Standard Proxy Storage Slots

Reference for detecting and inspecting proxy contracts per [EIP-1967](https://eips.ethereum.org/EIPS/eip-1967).

## Storage Slots

### Implementation Slot

```
bytes32 constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
// = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
```

- Stores the address of the current logic/implementation contract
- Used by: TransparentUpgradeableProxy, UUPSUpgradeable
- Read: `cast storage <PROXY> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
- The returned value is a 32-byte word; the address is the last 20 bytes

### Admin Slot

```
bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
// = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
```

- Stores the address of the ProxyAdmin contract (or admin EOA)
- Used by: TransparentUpgradeableProxy
- The admin is the only address that can call upgrade functions on the proxy
- In OpenZeppelin v5+, the admin is always a ProxyAdmin contract (never an EOA)

### Beacon Slot

```
bytes32 constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
// = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)
```

- Stores the address of the beacon contract
- Used by: BeaconProxy
- The beacon contract holds the implementation address for all its proxies

## Detecting Proxy Type

```bash
IMPL=$(cast storage <ADDR> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <RPC>)
ADMIN=$(cast storage <ADDR> 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url <RPC>)
BEACON=$(cast storage <ADDR> 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50 --rpc-url <RPC>)
```

| IMPL | ADMIN | BEACON | Pattern |
|------|-------|--------|---------|
| non-zero | non-zero | zero | TransparentUpgradeableProxy |
| non-zero | zero | zero | UUPSUpgradeable |
| zero | zero | non-zero | BeaconProxy |
| zero | zero | zero | Not a proxy (or non-ERC-1967) |

## OpenZeppelin Version Differences

### v4.x (used by Namefi)
- `TransparentUpgradeableProxy(logic, admin, data)` — admin is an address parameter
- ProxyAdmin is deployed separately and passed as `admin`
- ProxyAdmin stores its owner, who can call `upgrade()` and `upgradeAndCall()`

### v5.x
- `TransparentUpgradeableProxy(logic, initialOwner, data)` — creates a new ProxyAdmin internally
- ProxyAdmin is a child contract created via CREATE inside the constructor
- The ProxyAdmin address is deterministic based on the proxy's address and constructor nonce

## Querying ProxyAdmin Owner

```bash
# Get the ProxyAdmin address from the proxy's admin slot
ADMIN_ADDR=$(cast storage <PROXY> 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url <RPC>)

# Query the ProxyAdmin's owner
cast call $ADMIN_ADDR "owner()(address)" --rpc-url <RPC>
```

## Upgrade Call Signatures

```solidity
// ProxyAdmin (OZ v4)
function upgrade(TransparentUpgradeableProxy proxy, address implementation) external;
function upgradeAndCall(TransparentUpgradeableProxy proxy, address implementation, bytes memory data) external payable;

// UUPS (called on proxy directly)
function upgradeTo(address newImplementation) external;
function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
```
