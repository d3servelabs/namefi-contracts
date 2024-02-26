# Namefi Contracts

[![CI](https://github.com/d3servelabs/namefi-contracts/actions/workflows/ci.yml/badge.svg)](https://github.com/d3servelabs/namefi-contracts/actions/workflows/ci.yml)

Namefi was formerly known as "D3Bridge".

https://namefi.io

## Term
- *NFT*: NonFungibleToken
- *SC*: ServiceCredit
## Deployments

| Name | Address | Chain |
| ---- | ------- | ----- |
| NamefiProxyAdmin | 0x00000000009209F45C2822E3f11b7a73014130F1 | [Ethereum](https://etherscan.io/address/0x00000000009209f45c2822e3f11b7a73014130f1), [Sepolia](https://sepolia.etherscan.io/address/0x00000000009209f45c2822e3f11b7a73014130f1), [Goerli](https://goerli.etherscan.io/address/0x00000000009209f45c2822e3f11b7a73014130f1) |
| NamefiServiceCredit | 0x0000000000c39A0F674c12A5e63eb8031B550b6f | [Ethereum](https://etherscan.io/address/0x0000000000c39A0F674c12A5e63eb8031B550b6f), [Sepolia](https://sepolia.etherscan.io/address/0x0000000000c39A0F674c12A5e63eb8031B550b6f), [Goerli](https://Goerli.etherscan.io/address/0x0000000000c39A0F674c12A5e63eb8031B550b6f) |
| NamefiNFT | 0x0000000000cf80E7Cf8Fa4480907f692177f8e06 | [Ethereum](https://etherscan.io/address/0x0000000000cf80E7Cf8Fa4480907f692177f8e06), [Sepolia](https://sepolia.etherscan.io/address/0x0000000000cf80E7Cf8Fa4480907f692177f8e06), [Goerli](https://Goerli.etherscan.io/address/0x0000000000cf80E7Cf8Fa4480907f692177f8e06) |
| ---- | ------- | ----- |
| NamefiServiceCredit logic (V1) | 0x000000000283368D2e1200074DEf151D09B3a04a | [Ethereum](https://etherscan.io/address/0x000000000283368D2e1200074DEf151D09B3a04a), [Sepolia](https://sepolia.etherscan.io/address/0x000000000283368D2e1200074DEf151D09B3a04a), [Goerli](https://Goerli.etherscan.io/address/0x000000000283368D2e1200074DEf151D09B3a04a) |
| NamefiNFT logic (V1) | 0x00000000f34FA72595f0B1FA90718Cdd865D6d44 | [Ethereum](https://Ethereum.etherscan.io/address/0x00000000f34FA72595f0B1FA90718Cdd865D6d44), [Sepolia](https://sepolia.etherscan.io/address/0x00000000f34FA72595f0B1FA90718Cdd865D6d44), [Goerli](https://Goerli.etherscan.io/address/0x00000000f34FA72595f0B1FA90718Cdd865D6d44) |

## Step of Deployment

The following `goerli` can be replaced with other chain name.

### Step 1: Deploy ProxyAdmin

```sh
```sh
npx hardhat namefi-nick-deploy-proxy-admin --network goerli --nonce 0x00000000000000000000000000000000000000005715a2bbff5b843d84e1daf8
```

When failed to verify: 

```sh
npx hardhat verify --network goerli --contract contracts/NamefiProxyAdmin.sol:NamefiProxyAdmin 0x00000000009209F45C2822E3f11b7a73014130F1 0x01Bf7f00540988622a32de1089B7DeA09a867188
```

### Step 2: Deploy NFT

Deploy NFT logic contract


```sh
npx hardhat namefi-nick-deploy-logic --network goerli --logic-contract-name NamefiNFT --nonce 0x0000000000000000000000000000000000000000de26213fdd792730e8a811cb --dry-run
```

Should expect new address: `0x00000000f34FA72595f0B1FA90718Cdd865D6d44` (deterministic)

When failed to verify

```sh
npx hardhat verify --network goerli --contract contracts/NamefiNFT.sol:NamefiNFT 0x00000000f34FA72595f0B1FA90718Cdd865D6d44
```

Then Deploy the NFT proxy contract

```sh
npx hardhat namefi-nick-deploy-proxy --network goerli --logic-contract-name NamefiNFT --logic-address 0x00000000f34FA72595f0B1FA90718Cdd865D6d44 --admin-address 0x00000000009209F45C2822E3f11b7a73014130F1 --nonce 0x0000000000000000000000000000000000000000ebf9c231fad1d33999ec0da2 --dry-run
```

### Step 3: Deploy Service Credit


Deploy Service Credit logic contract

```sh
npx hardhat namefi-nick-deploy-logic --network goerli --logic-contract-name NamefiServiceCredit --nonce 0x00000000000000000000000000000000000000005c3c1f7f262e7a0fa9eaa081 --dry-run
```
(could not replay, so we use the transaction data)


Deploy the Service Credit proxy contract

```sh
npx hardhat namefi-nick-deploy-proxy --network goerli --logic-contract-name NamefiServiceCredit --logic-address 0x000000000283368D2e1200074DEf151D09B3a04a --admin-address 0x00000000009209F45C2822E3f11b7a73014130F1 --nonce 0x0000000000000000000000000000000000000000489dffcf4b44ee1731dc251d --dry-run
```

### Step 5: Other Misc

Then 

- Call `NamefiNFT.setServiceCreditAddress(NamefiServiceCredit.address)` https://sepolia.etherscan.io/tx/0x23341a41bd65fb4be07796f44c8cbb0b56068128c545a1540a324f0b71ed381e
- Call `NamefiServiceCredit.grantRole(CHARGER_ROLE, NamefiNFT.address)` https://sepolia.etherscan.io/tx/0x854d9501afa3a50a0e8321275587731352877ec9002932a44f58754b26ddf65c

## D3Bridge (Legacy)

### ABI for NFT

```
[
    'function safeMintByNameNoCharge(address to, string memory domainName, uint256 expirationTime )',
    'function safeMintByNameWithCharge(address to, string memory domainName, uint256 expirationTime, address chargee, bytes memory extraData)',
    'function balanceOf(address owner) public view returns (uint256)',
    'function ownerOf(uint256 tokenId) public view returns (address)',
    'function name() public view returns (string memory)',
    'function tokenURI(uint256 tokenId) public view returns (string memory)',
    'function idToNormalizedDomainName(uint256 tokenId) public view returns (string memory)',
    'function normalizedDomainNameToId(string memory domainName) public pure returns (uint256)',
    'function burnByName(string memory domainName) public',
    'function lockByName(string memory domainName) public',
    'function unlockByName(string memory domainName) public',

    /*region Lockable*/
    'function isLocked(uint256 tokenId, bytes32 calldata extra) public view returns (bool)',
    
    /*endregion Lockable*/
]
```
### ABI for ERC20

### Latest (Sepolia)

| Name                | Address                                                                                                                            |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| NFT Proxy           | [0x7B6bEf228F123741446DcFEf030a2E4cee519144](https://sepolia.etherscan.io/address/0x7B6bEf228F123741446DcFEf030a2E4cee519144#code) |
| NFT Logic(v.0.0.8)  | [0x32f73FF1d3aa5936351EfE4043e5cB4207D26E5B](https://sepolia.etherscan.io/address/0x32f73FF1d3aa5936351EfE4043e5cB4207D26E5B#code) |
| SC Proxy            | [0x7dce171E04AdB3a2769918380B7604c685242320](https://sepolia.etherscan.io/address/0x7dce171E04AdB3a2769918380B7604c685242320#code) |
| SC Logic(v.0.2.0)   | [0x44c4c5a92754eC64F70712D5FB22036DdFc9a975](https://sepolia.etherscan.io/address/0x44c4c5a92754eC64F70712D5FB22036DdFc9a975#code) |
| ProxyAdmin (both)   | [0xA016886d155D6c82e0Cc59103920802121929F8f](https://sepolia.etherscan.io/address/0xA016886d155D6c82e0Cc59103920802121929F8f#code) |
|-------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| TestERC20           | [0x10b3b4B4A8DeD1b2D7d826804Ec3B01379d909DD](https://sepolia.etherscan.io/address/0x10b3b4B4A8DeD1b2D7d826804Ec3B01379d909DD#code) |

### v0.0.3 (Sepolia)

| Name                | Address                                                                                                                            |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| NFT Proxy           | [0x7B6bEf228F123741446DcFEf030a2E4cee519144](https://sepolia.etherscan.io/address/0x7B6bEf228F123741446DcFEf030a2E4cee519144#code) |
| NFT Logic           | [0x406bF616b6694273cC9E789C2FF46Ac3f4B68dF8](https://sepolia.etherscan.io/address/0x406bF616b6694273cC9E789C2FF46Ac3f4B68dF8#code) |
| SC Proxy            | [0x7dce171E04AdB3a2769918380B7604c685242320](https://sepolia.etherscan.io/address/0x7dce171E04AdB3a2769918380B7604c685242320#code) |
| SC Logic            | [0x7c09E3cdfA63fBfaBAfbaB342fdFE31845a20439](https://sepolia.etherscan.io/address/0x7c09E3cdfA63fBfaBAfbaB342fdFE31845a20439#code) |
| ProxyAdmin (both)   | [0xA016886d155D6c82e0Cc59103920802121929F8f](https://sepolia.etherscan.io/address/0xA016886d155D6c82e0Cc59103920802121929F8f#code) |

### v0.0.2 (Sepolia)
| Name       | Address |
| ---------- | ------- |
| Logic      | [0x4da21b5c095184C1822014cBc7173a11f9dE56BA](https://sepolia.etherscan.io/address/0x4da21b5c095184C1822014cBc7173a11f9dE56BA#code) |
| ProxyAdmin | [0xA016886d155D6c82e0Cc59103920802121929F8f](https://sepolia.etherscan.io/address/0xA016886d155D6c82e0Cc59103920802121929F8f#code) |
| Proxy      | [0x7B6bEf228F123741446DcFEf030a2E4cee519144](https://sepolia.etherscan.io/address/0x7B6bEf228F123741446DcFEf030a2E4cee519144#code) |

### v0.0.1 (Goerli)
| Name       | Address |
| ---------- | ------- |
| Logic     | [0x9765eFf10c752DB8Ef81fe655cEB1543AbE7b16D](https://goerli.etherscan.io/address/0x9765eFf10c752DB8Ef81fe655cEB1543AbE7b16D#writeContract) |
