// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ExpirableNFT.sol";
import "./LockableNFT.sol";
import "./IChargeableERC20.sol";

/** @custom:security-contact team@d3serve.xyz
 * @custom:version V0.0.2
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
contract D3BridgeNFT is 
        Initializable, 
        ERC721Upgradeable, 
        AccessControlUpgradeable, 
        ExpirableNFT,
        LockableNFT {
    string private _baseUriStr;  // Storage Slot
    mapping(uint256 id => string) private _idToDomainNameMap; //  Storage Slot
    IChargeableERC20 public _d3BridgeServiceCreditContract;  // Storage Slot

    // Currently MINTER_ROLE is used for minting, burning and updating expiration time
    // until we have need more fine-grain control.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    uint256 public constant CHARGE_PER_YEAR = 20 * 10 ** 18; // 20 D3BSC // TODO: decide charge amount

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

    function _safeMintByName(
        address to, 
        string memory domainName,
        uint256 expirationTime // unix timestamp
    ) internal virtual onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = domainName;
        require(expirationTime > block.timestamp, "D3BridgeNFT: expiration time too early");
        _setExpiration(tokenId, expirationTime);
        _safeMint(to, tokenId);
    }

    function safeMintByNameNoCharge(
        address to, 
        string memory domainName,
        uint256 expirationTime // unix timestamp
    ) external virtual onlyRole(MINTER_ROLE) {
        _safeMintByName(to, domainName, expirationTime);
    }

    function _currentChargePerYear(string memory /*domainName*/) internal pure returns (uint256) {
        return CHARGE_PER_YEAR;
    }

    function currentChargeAmountPerYear(string memory domainName) external pure returns (uint256) {
        return _currentChargePerYear(domainName);
    }

    function safeMintByNameWithCharge(
        address to,
        string memory domainName,
        uint256 expirationTime, // unix timestamp
        address chargee,
        bytes memory /*extraData*/
    ) external virtual onlyRole(MINTER_ROLE) {
        require(_d3BridgeServiceCreditContract != IChargeableERC20(address(0)), "D3BridgeNFT: service credit contract not set");
        // TODO: audit to protect from reentry attack
        bytes32 result = _d3BridgeServiceCreditContract.charge(
            address(this), 
            chargee, 
            _currentChargePerYear(domainName), 
            // add string reason "D3BridgeNFT: mint" + domainName in one string
            string(abi.encodePacked("D3BridgeNFT: mint ", domainName)),
            bytes("")
        );

        require(result == keccak256("SUCCESS"), "D3BridgeNFT: charge failed");
        _safeMintByName(to, domainName, expirationTime);
    }

    function burnByName(string memory domainName) public 
        onlyRole(MINTER_ROLE)
        whenLocked(normalizedDomainNameToId(domainName), bytes("")) {
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
        whenNotLocked(tokenId, bytes(""))
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

    function lock(uint256 tokenId, bytes calldata extra) external payable override onlyRole(MINTER_ROLE) {
        _lock(tokenId, extra);
    }
    function lockByName(string memory domainName) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _lock(tokenId, bytes(""));
    }

    function unlock(uint256 tokenId, bytes calldata extra) external payable override onlyRole(MINTER_ROLE) {
        _unlock(tokenId, extra);
    }

    function unlockByName(string memory domainName) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _unlock(tokenId, bytes(""));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setServiceCreditContract(address addr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _d3BridgeServiceCreditContract = IChargeableERC20(addr);
    }
}