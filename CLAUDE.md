# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Package Manager
- Uses **Bun** as package manager (`packageManager: "bun@1.1.0"`)

### Testing
- `bun test` - Run both Hardhat and Foundry tests
- `bun test:hardhat` - Run TypeScript/JavaScript tests using Hardhat
- `bun test:forge` - Run Solidity tests using Foundry
- `forge test` - Direct Foundry test execution
- `forge test --gas-report -vv` - Run tests with detailed gas reporting
- `forge snapshot` - Create gas usage snapshots for comparison

### Compilation & Building  
- `bun compile` - Compile contracts using Hardhat
- `hardhat compile` - Direct Hardhat compilation
- `bun clean` - Clean compiled artifacts

### Coverage & Analysis
- `bun coverage` - Generate test coverage reports
- `bun forge:gas` - Generate gas usage reports with Foundry
- `bun forge:gas-snapshot` - Create gas snapshots
- `bun forge:gas-snapshot:check` - Verify gas snapshots haven't regressed

### Code Generation
- `bun gen712` - Generate EIP712 struct code from namefi-struct.js

### Development Setup
- `bun install` - Install dependencies and auto-setup Foundry
- `bun forge:setup` - Manual Forge standard library setup if needed

## Architecture Overview

### Core Contracts
This is a domain name NFT system with service credit functionality:

1. **NamefiNFT** - Main NFT contract for domain names
   - Inherits from ExpirableNFT and LockableNFT
   - Handles domain name minting, burning, and transfers
   - Integrates with service credit system for charging
   - Supports EIP712 signatures for authorized operations

2. **NamefiServiceCredit** - ERC20 token for service payments
   - Chargeable ERC20 with role-based access control
   - Supports batch operations (mint, transfer)
   - Buyable with ETH or other supported tokens
   - Has charger roles for authorized charging

3. **ExpirableNFT** - Base contract for NFTs with expiration dates
   - Manages token expiration logic
   - Prevents operations on expired tokens

4. **LockableNFT** - Base contract for lockable NFTs
   - Provides locking/unlocking functionality
   - Restricts transfers of locked tokens

5. **NamefiProxyAdmin** - Upgradeable proxy administration
   - Manages contract upgrades for the system

### Contract Inheritance Structure
```
NamefiNFT extends ExpirableNFT, LockableNFT, ERC721Upgradeable, AccessControlUpgradeable
NamefiServiceCredit extends ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable
```

### Deployment Pattern
- Uses OpenZeppelin's upgradeable proxy pattern
- Deterministic deployment addresses across networks
- Separate logic and proxy contracts for upgradeability

## Testing Structure

### Hardhat Tests (test/)
- TypeScript tests for integration and complex scenarios
- Tests in: `eip712.test.ts`, `name.test.ts`, `nft-mint.test.ts`, `nft.test.ts`, `service-credit.test.ts`

### Foundry Tests (test/foundry/)
- Solidity unit tests with gas profiling
- Separate test files for each major contract
- Gas usage analysis and optimization testing

## Network Configuration

### Supported Networks
- Mainnet, Sepolia, Goerli (deprecated), Base, Mumbai, Polygon
- Uses Infura and Alchemy for RPC endpoints
- Configured etherscan verification for all networks

### Environment Variables Required
- `MNEMONIC` - Deployment account mnemonic
- `INFURA_API_KEY` - Infura project key
- `ALCHEMY_API_KEY` - Alchemy project key  
- `ETHERSCAN_API_KEY` - Etherscan verification key
- `BASESCAN_API_KEY` - Base network verification key
- `POLYGONSCAN_API_KEY` - Polygon verification key

## Gas Optimization

The project includes comprehensive gas profiling:
- Foundry gas reports target specific contracts: NamefiNFT, ExpirableNFT, LockableNFT, NamefiServiceCredit
- Use `bun forge:gas` for detailed gas analysis
- Gas snapshots track optimization progress over time

## Hardhat Tasks

Custom deployment and management tasks in `tasks/`:
- `deploy.ts` - Standard deployment scripts
- `nick-deploy.ts` - Deterministic deployment (CREATE2)
- `mgmt.ts` - Contract management operations
- `get-tx.ts` - Transaction utilities

## Solidity Version & Settings
- Solidity ^0.8.20 (contracts), 0.8.24 (compilation)
- Optimizer enabled with 200 runs
- Storage layout output enabled for upgradeable contracts