// SPDX-License-Identifier: Proprietary
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact team@d3serve.xyz
contract D3BridgeNFT is ERC721, Ownable {
    constructor() ERC721("D3BridgeNFT", "D3B") {}
    mapping(uint256 => string) private _idToDomainNameMap;

    function idToNormalizedDomainName(uint256 tokenId) public view returns (string memory) {
        return _idToDomainNameMap[tokenId];
    }

    function normalizedDomainNameToId(string memory domainName) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(domainName)));
    }

    function safeMintByName(address to, string memory domainName) public onlyOwner {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = domainName;
        _safeMint(to, tokenId);
    }

    function safeTransferFromByName(address from, address to, string memory domainName) public {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = domainName;
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, "");
    }

    function burnByName(string memory domainName) public onlyOwner {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = "";
        _burn(tokenId);
    }
}