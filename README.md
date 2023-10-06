# D3Bridge NFT
[![CI](https://github.com/d3servelabs/d3bridge-nft/actions/workflows/ci.yml/badge.svg)](https://github.com/d3servelabs/d3bridge-nft/actions/workflows/ci.yml)

## Term
- *NFT*: NonFungibleToken
- *SC*: ServiceCredit
## Deployments

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
| NFT Logic(v.0.0.5)  | [0xAc046867b6266e6a3df427A60273F36f208E790a](https://sepolia.etherscan.io/address/0xAc046867b6266e6a3df427A60273F36f208E790a#code) |
| SC Proxy            | [0x7dce171E04AdB3a2769918380B7604c685242320](https://sepolia.etherscan.io/address/0x7dce171E04AdB3a2769918380B7604c685242320#code) |
| SC Logic            | [0x7c09E3cdfA63fBfaBAfbaB342fdFE31845a20439](https://sepolia.etherscan.io/address/0x7c09E3cdfA63fBfaBAfbaB342fdFE31845a20439#code) |
| ProxyAdmin (both)   | [0xA016886d155D6c82e0Cc59103920802121929F8f](https://sepolia.etherscan.io/address/0xA016886d155D6c82e0Cc59103920802121929F8f#code) |


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
