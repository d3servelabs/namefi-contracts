
// SPDX-License-Identifier: Apache-2.0+
// Author: Team Namefi by D3ServeLabs
// https://namefi.io
// https://d3serve.xyz
// Security Contact: security@d3serve.xyz

pragma solidity 0.8.19;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
/** 
 * @custom:security-contact security@d3serve.xyz
 * @custom:version V1.0.0
 * The ABI of this interface in javascript array such as
```
[
    "function idToNormalizedDomainName(uint256 tokenId) public view returns (string memory)",
    "function normalizedDomainNameToId(string memory domainName) public pure returns (uint256)",
    "function safeMintByNameNoCharge(address to, string memory domainName, uint256 expirationTime) external virtual",
    "function safeMintByNameWithCharge(address to, string memory domainName, uint256 expirationTime, address chargee, bytes memory extraData) external virtual",
    "function burnByName(string memory domainName) external",
    "function safeTransferFromByName(address from, address to, string memory domainName) public",
    "function setBaseURI(string memory baseUriStr) public",
    "function setExpiration(uint256 tokenId, uint256 expirationTime) public",
    "function lock(uint256 tokenId, bytes calldata extra) external payable virtual",
    "function lockByName(string memory domainName) external",
    "function unlock(uint256 tokenId, bytes calldata extra) external payable virtual",
    "function unlockByName(string memory domainName) external",
    "function currentChargeAmountPerYear(string memory domainName) external pure returns (uint256)",
    "function setServiceCreditContract(address addr) public"
]
```
*/
contract NamefiProxyAdmin is ProxyAdmin { 
    constructor(address initialOwner) ProxyAdmin() {
        _transferOwnership(initialOwner);
    }
}