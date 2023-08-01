// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact team@d3serve.xyz
contract D3BridgeNFT is ERC721, Ownable {
    constructor() ERC721("D3BridgeNFT", "D3B") {}
    mapping(uint256 => string) private _idToDomainNameMap;
    
    function validateNormalizedDomainName(string memory domainName) public returns (bool) {
        // require that the domain name is normalized
        // regex a-z0-9-\.+
        // require that the domain name is not too long
        // require that the domain name is not too short
        // TODO implement
        return true;
    }

    function idToDomainName(uint256 tokenId) public view returns (string memory) {
        return _idToDomainNameMap[tokenId];
    }

    function domainNameToId(string memory domainName) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(domainName)));
    }

    function safeMint(address to, string memory domainName) public onlyOwner {
        uint256 tokenId = domainNameToId(domainName);
        _idToDomainNameMap[tokenId] = domainName;
        _safeMint(to, tokenId);
    }

    function safeTransferFrom(address from, address to, string memory domainName) public {
        uint256 tokenId = domainNameToId(domainName);
        _idToDomainNameMap[tokenId] = domainName;
        _safeTransfer(from, to, tokenId, "");
    }

    function burn(string memory domainName) public onlyOwner {
        uint256 tokenId = domainNameToId(domainName);
        _idToDomainNameMap[tokenId] = "";
        _burn(tokenId);
    }
}