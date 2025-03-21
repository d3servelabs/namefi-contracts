# Namefi Contracts

[![CI](https://github.com/d3servelabs/namefi-contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/d3servelabs/namefi-contracts/actions/workflows/ci.yml)

Namefi was formerly known as "D3Bridge". Report bug to get bounty rewards! See #Bounty Section

https://namefi.io

## Term
- *NFT*: NonFungibleToken
- *SC*: ServiceCredit

## Development

### Generating ABIs
To generate ABI JSON files for all contracts, run:

```bash
yarn gen:abi
```

This will create ABI files in the `abis` directory.

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
