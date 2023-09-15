// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ExpirableNFT.sol";
import "./LockableNFT.sol";

/// @custom:security-contact team@d3serve.xyz
/// @custom:version V0.0.2
contract D3BridgeNFT is 
        Initializable, 
        ERC721Upgradeable, 
        AccessControlUpgradeable, 
        ExpirableNFT,
        LockableNFT {
    string private _baseUriStr;
    mapping(uint256 id => string) private _idToDomainNameMap;

    // Currently MINTER_ROLE is used for minting, burning and updating expiration time
    // until we have need more fine-grain control.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("D3BridgeNFT", "D3B");
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _baseUriStr = "https://d3serve.xyz/nft/";
    }

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
    ) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = domainName;
        require(expirationTime > block.timestamp, "D3BridgeNFT: expiration time too early");
        _setExpiration(tokenId, expirationTime);
        _safeMint(to, tokenId);
    }

    function burnByName(string memory domainName) public 
        onlyRole(MINTER_ROLE)
        whenLocked(normalizedDomainNameToId(domainName)) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = "";
        _burn(tokenId);
    }

    function safeTransferFromByName(address from, address to, string memory domainName) public {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _idToDomainNameMap[tokenId] = domainName;
        _safeTransfer(from, to, tokenId, "");
    }

    function _transfer(address from, address to, uint256 tokenId) 
        whenNotLocked(tokenId)
        whenNotExpired(tokenId)
        internal virtual override {
        super._transfer(from, to, tokenId);
    }

    // URI
    function _baseURI() internal view override returns (string memory) {
        return _baseUriStr;
    }

    function setBaseURI(string memory baseUriStr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseUriStr = baseUriStr;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "D3BridgeNFT: URI query for nonexistent token");
        return string(abi.encodePacked(_baseURI(), _idToDomainNameMap[tokenId]));
    }

    function setExpiration(uint256 tokenId, uint256 expirationTime) public override onlyRole(MINTER_ROLE) {
        _setExpiration(tokenId, expirationTime);
    }

    function lockByName(string memory domainName) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _lock(tokenId);
    }

    function unlockByName(string memory domainName) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _unlock(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}