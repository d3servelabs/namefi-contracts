# Namefi Contracts

[![CI](https://github.com/d3servelabs/namefi-contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/d3servelabs/namefi-contracts/actions/workflows/ci.yml)

Namefi was formerly known as "D3Bridge". Report bug to get bounty rewards! See #Bounty Section

https://namefi.io

## Term
- *NFT*: NonFungibleToken
- *SC*: ServiceCredit
## Deployments

- NamefiProxyAdmin: `0x00000000009209F45C2822E3f11b7a73014130F1`
    - [Ethereum](https://etherscan.io/address/0x00000000009209f45c2822e3f11b7a73014130f1) 
    - [Base](https://basescan.org/address/0x00000000009209f45c2822e3f11b7a73014130f1) 
    - [Sepolia](https://sepolia.etherscan.io/address/0x00000000009209f45c2822e3f11b7a73014130f1)
    - [Goerli](https://goerli.etherscan.io/address/0x00000000009209f45c2822e3f11b7a73014130f1)
    - [Mumbai](https://mumbai.polygonscan.com/address/0x00000000009209f45c2822e3f11b7a73014130f1)

- NamefiServiceCredit: `0x0000000000c39A0F674c12A5e63eb8031B550b6f`
    - [Ethereum](https://etherscan.io/address/0x0000000000c39A0F674c12A5e63eb8031B550b6f)
    - [Base](https://basescan.org/address/0x0000000000c39A0F674c12A5e63eb8031B550b6f) 
    - [Sepolia](https://sepolia.etherscan.io/address/0x0000000000c39A0F674c12A5e63eb8031B550b6f)
    - [Goerli](https://Goerli.etherscan.io/address/0x0000000000c39A0F674c12A5e63eb8031B550b6f)
    - [Mumbai](https://mumbai.polygonscan.com/address/0x0000000000c39A0F674c12A5e63eb8031B550b6f)

- NamefiNFT: `0x0000000000cf80E7Cf8Fa4480907f692177f8e06`
    - [Ethereum](https://etherscan.io/address/0x0000000000cf80E7Cf8Fa4480907f692177f8e06)
    - [Base](https://basescan.org/address/0x0000000000cf80E7Cf8Fa4480907f692177f8e06) 
    - [Sepolia](https://sepolia.etherscan.io/address/0x0000000000cf80E7Cf8Fa4480907f692177f8e06)
    - [Goerli](https://Goerli.etherscan.io/address/0x0000000000cf80E7Cf8Fa4480907f692177f8e06)
    - [Mumbai](https://mumbai.polygonscan.com/address/0x0000000000cf80E7Cf8Fa4480907f692177f8e06)

## Logic Contracts
- NamefiServiceCredit logic (V1.3.0): `0x0000000008f774D350fDb33Fe8D81a230de2ea89` (nonce=`0x00000000000000000000000000000000000000006101b4b3a13d8701198a0cb5`)
    - [Ethereum](https://etherscan.io/address/0x0000000008f774D350fDb33Fe8D81a230de2ea89)
    - [Base](https://basescan.org/address/0x0000000008f774D350fDb33Fe8D81a230de2ea89) 
    - [Sepolia](https://sepolia.etherscan.io/address/0x0000000008f774D350fDb33Fe8D81a230de2ea89)
    - Goerli - deprecated
    - [Mumbai](https://mumbai.polygonscan.com/address/0x0000000008f774D350fDb33Fe8D81a230de2ea89)

- NamefiNFT logic (V1.2.0): `0x0000000066fC23B730b11098610416207db60AD7` (nonce=`0x00000000000000000000000000000000000000008f97345e74a9ce2`)
    - [Ethereum](https://etherscan.io/address/0x0000000066fC23B730b11098610416207db60AD7)
    - [Base](https://basescan.org/address/0x0000000066fC23B730b11098610416207db60AD7) 
    - [Sepolia](https://sepolia.etherscan.io/address/0x0000000066fC23B730b11098610416207db60AD7)
    - [Goerli](https://Goerli.etherscan.io/address/0x0000000066fC23B730b11098610416207db60AD7)
    - [Mumbai](https://mumbai.polygonscan.com/address/0x0000000066fC23B730b11098610416207db60AD7)

## Bounty

The D3Serve Labs also provide a bug bounty for the following 
reward for reporting bugs or security flaws. 

|  Level              | Bounty Reward                        | Explain  |
| ---------------------- | ------------------------------------ | -------- |
| Kudo                  | 300 $NFSC or 0.1ETH                              | Fixes are nice to have or minor improvements |
| Essential                 | 900 $NFSC or 0.3ETH                              | Bugs that are affecting usage or security but don't require urgent upgrade for fixing it.  |
| Critical               | 3000 $NFSC or 1ETH                                 | Bugs that requires an urgent upgrade |
| Fatal      | 20% of Fund Recovered | Bugs or security flaws that requires recovery of fund |

(Active D3Serve Labs compansated teammates are disqualified to participate this bounty program but other internal bonuses will be rewarded.)

### v0.0.1 (Goerli)
| Name       | Address |
| ---------- | ------- |
| Logic     | [0x9765eFf10c752DB8Ef81fe655cEB1543AbE7b16D](https://goerli.etherscan.io/address/0x9765eFf10c752DB8Ef81fe655cEB1543AbE7b16D#writeContract) |

## Gas Profiling with Foundry

This project includes Foundry integration for detailed gas profiling of smart contract functions. Foundry provides more comprehensive gas usage analysis compared to Hardhat, including internal function calls.

### Foundry Setup

The Foundry installer is automatically downloaded when you run `bun install`. To complete the setup:

1. After `bun install` completes, run the following in a new terminal window:
   ```bash
   # Activate Foundry in your current shell
   source ~/.bashrc  # or ~/.zshrc depending on your shell
   # Complete Foundry installation
   foundryup
   # Set up Forge dependencies
   bun forge:setup
   ```

The `lib/forge-std` directory is excluded from Git tracking via .gitignore.

### Running Gas Profiling Tests

```bash
# Run all Foundry tests
bun forge:test

# Run tests with gas reporting
bun forge:gas

# Create a gas snapshot for comparison
bun forge:snapshot
```

### Gas Profiling in Solidity Tests

Gas profiling can be done at a granular level using the `gasleft()` function:

```solidity
// Example from test/foundry/NamefiNFT.t.sol
function testFunction() public view {
    uint256 gasStart = gasleft();
    bool result = contract.someFunction();
    uint256 gasUsed = gasStart - gasleft();
    
    console.log("Gas used: ", gasUsed);
}
```

See `test/foundry/NamefiNFT.t.sol` for examples of gas profiling tests.
