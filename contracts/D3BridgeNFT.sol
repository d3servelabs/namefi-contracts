// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ExpirableNFT.sol";
import "./LockableNFT.sol";

/// @custom:security-contact team@d3serve.xyz
/// @custom:version V0.0.2
contract D3BridgeNFT is ERC721, Ownable, ExpirableNFT, LockableNFT {
    mapping(uint256 id => string) private _idToDomainNameMap;

    constructor() ERC721("D3BridgeNFT", "D3B") {}

    function idToNormalizedDomainName(uint256 tokenId) public view returns (string memory) {
        return _idToDomainNameMap[tokenId];
    }

    function normalizedDomainNameToId(string memory domainName) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(domainName)));
    }

    function safeMintByName(
        address to, 
        string memory domainName,
        uint256 expirationTime // unix timestamp
    ) public onlyOwner {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = domainName;
        _setExpiration(tokenId, expirationTime);
        require(expirationTime > block.timestamp, "D3BridgeNFT: expired");
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

    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        require(!isLocked(tokenId), "D3BridgeNFT: locked");
        require(!_isExpired(tokenId), "D3BridgeNFT: expired");
        super._transfer(from, to, tokenId);
    }

    // URI
    function _baseURI() internal pure override returns (string memory) {
        return "https://d3serve.xyz/nft/";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "D3BridgeNFT: URI query for nonexistent token");
        return string(abi.encodePacked(_baseURI(), _idToDomainNameMap[tokenId]));
    }

    function setExpiration(uint256 tokenId, uint256 expirationTime) public override onlyOwner {
        _setExpiration(tokenId, expirationTime);
    }
}