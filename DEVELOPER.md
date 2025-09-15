
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

Then Deploy the NFT proxy contract

```sh
npx hardhat namefi-nick-deploy-proxy --network goerli --logic-contract-name NamefiNFT --logic-address 0x00000000f34FA72595f0B1FA90718Cdd865D6d44 --admin-address 0x00000000009209F45C2822E3f11b7a73014130F1 --nonce 0x0000000000000000000000000000000000000000ebf9c231fad1d33999ec0da2 --dry-run
```

### Step 3: Deploy Service Credit


Deploy Service Credit logic contract

```sh
npx hardhat namefi-nick-deploy-logic --network goerli --logic-contract-name NamefiServiceCredit --nonce 0x00000000000000000000000000000000000000005c3c1f7f262e7a0fa9eaa081 --dry-run
```

Checkout git commit: fa893a4a6bf66c952ea12131871bd99307112fa3, and 
don't forget to *re-compile* the contract.

Deploy the Service Credit proxy contract

```sh
npx hardhat namefi-nick-deploy-proxy --network goerli --logic-contract-name NamefiServiceCredit --logic-address 0x000000000283368D2e1200074DEf151D09B3a04a --admin-address 0x00000000009209F45C2822E3f11b7a73014130F1 --nonce 0x0000000000000000000000000000000000000000489dffcf4b44ee1731dc251d --dry-run
```

### Step 5: Grant permissions

#### Setup NamefiNFT and NamefiServiceCredit 

- Call `NamefiNFT.setServiceCreditContract(NamefiServiceCredit.address)` https://sepolia.etherscan.io/tx/0x23341a41bd65fb4be07796f44c8cbb0b56068128c545a1540a324f0b71ed381e

```sh
npx hardhat namefi-set-nfsc-address --network goerli
```

and then

- Call `NamefiServiceCredit.grantRole(CHARGER_ROLE, NamefiNFT.address)` https://sepolia.etherscan.io/tx/0x854d9501afa3a50a0e8321275587731352877ec9002932a44f58754b26ddf65c

#### Grant NamefiNFT Minter to KMS Account

```sh
npx hardhat namefi-grant-nft-minter --minter 0xEe15C2735eD48C80f50fe666b45fE9ec699daEE5 --network goerli
```

#### Grant NamefiServiceCredit Minter to D3Serve Labs Dev Admin Accounts

```sh
npx hardhat namefi-grant-nfsc-minter --minter 0x1b0f291c8fFebE891886351CDfF8A304a840C8Ad --network goerli
```
## Historical Deployment

### Notes

#### Upgrade to v1.4.0-rc1 NamefiNFT

Step 0: Re-compile the contract!
Make sure to re-compile the contract! Otherwise the verification will fail.

Step 1: Mine the nonce
```
npx hardhat namefi-mine-nonce --contract NamefiNFT
```


Step 2: Get the transaction data
```
npx hardhat namefi-manual-deploy --contract NamefiNFT --nonce 0x19e9cc052fb15e8191ebd19f59d8c1c2574b45beeb5a2b7f81a37acc38da04eb > tx.md
```
Gets the transaction data to upgrade to v1.4.0-rc1

Step 3: Deploy the new logic contract of NamefiNFT onto Seplia

- [TX info on Etherscan](https://sepolia.etherscan.io/tx/0x422ef2bc3ae6e17cc3d407b573297d49a7617f5d4a927d0227e5c948e1c9d230)

- [TX info on Gnosis Safe](https://app.safe.global/transactions/tx?safe=sep:0xFafa4243Ec016187E03388d70B7c5819616C44D5&id=multisig_0xFafa4243Ec016187E03388d70B7c5819616C44D5_0x4d2ca97ba61328d8b9b7473177caefcd07a43e2e9448c066417bc1c7bed8d025)


Step 4: Upgrade the NamefiNFT proxy contract on Sepolia

NamefiNFT Proxy address is 0x0000000000cf80E7Cf8Fa4480907f692177f8e06
Admin address is 0x00000000009209F45C2822E3f11b7a73014130F1
Go to Admin Address: https://sepolia.etherscan.io/address/0x00000000009209f45c2822e3f11b7a73014130f1#code

Write Contract: 
proxy (address) = 0x0000000000cf80E7Cf8Fa4480907f692177f8e06
implementation (address) = 0x00008eea299efc29d7bdafec0465feaa828064fa

- [TX info on Etherscan](https://sepolia.etherscan.io/tx/0x113424ef95c5039f86d309e239fe7f741a450b4ba5dfa8668f13eaff9c6ec506)


Step 5: Verify the upgrade transaction

5.1: Verify on the sepolia.etherscan.io

```
npx hardhat verify --network sepolia --contract contracts/NamefiNFT.sol:NamefiNFT 0x00008eea299efc29d7bdafec0465feaa828064fa
```

```
❯ npx hardhat verify --network sepolia --contract contracts/NamefiNFT.sol:NamefiNFT 0x00008eea299efc29d7bdafec0465feaa828064fa
Nothing to compile
No need to generate any newer typings.
Warning: Unused function parameter. Remove or comment out the variable name to silence this warning.
   --> contracts/NamefiNFT.sol:399:9:
    |
399 |         bytes memory extraData) external virtual onlyRole(MINTER_ROLE) {
    |         ^^^^^^^^^^^^^^^^^^^^^^


Successfully submitted source code for contract
contracts/NamefiNFT.sol:NamefiNFT at 0x00008eea299efc29d7bdafec0465feaa828064fa
for verification on the block explorer. Waiting for verification result...

Successfully verified contract NamefiNFT on Etherscan.
https://sepolia.etherscan.io/address/0x00008eea299efc29d7bdafec0465feaa828064fa#code
```

5.2 Verify on blockscout.com

```
npx hardhat verify --network sepolia_blockscout --contract contracts/NamefiNFT.sol:NamefiNFT 0x00008eea299efc29d7bdafec0465feaa828064fa
```

But it stuck for 5min and didn't proceed.

#### Upgrade to v1.2.0

```sh
npx hardhat namefi-nick-deploy-logic --logic-contract-name NamefiNFT --nonce 0x00000000000000000000000000000000000000000efaaba64cf8043a8b549f63  --network base --dry-run

npx hardhat namefi-upgrade --proxy-address 0x0000000000cf80E7Cf8Fa4480907f692177f8e06 --logic-address 0x0000000066fC23B730b11098610416207db60AD7 --network base

npx hardhat namefi-nick-deploy-logic --logic-contract-name NamefiServiceCredit --nonce 0x00000000000000000000000000000000000000008f97345e74a9ce21a05b6887  --network base --dry-run

npx hardhat namefi-upgrade --proxy-address 0x0000000000c39A0F674c12A5e63eb8031B550b6f --logic-address 0x000000005BF3eae7b67eC767e45262d26106ED93 --network base
```

### Set BaseURI

```sh
npx hardhat namefi-set-base-uri --new-base-uri https://md.namefi.dev/goerli/ --network goerli
npx hardhat namefi-set-base-uri --new-base-uri https://md.namefi.dev/mumbai/ --network mumbai
npx hardhat namefi-set-base-uri --new-base-uri https://md.namefi.run/sepolia/ --network sepolia
npx hardhat namefi-set-base-uri --new-base-uri https://md.namefi.io/base/ --network base
```

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
