// SPDX-License-Identifier: Apache-2.0+
// Author: Team Namefi by D3ServeLabs
// https://namefi.io
// https://d3serve.xyz
// Security Contact: security@d3serve.xyz

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC5267Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";

import "./ExpirableNFT.sol";
import "./LockableNFT.sol";
import "./IChargeableERC20.sol";
import "./NamefiStruct.sol";

error NamefiNFT_DomainNameNotNomalized(string domainName);
error NamefiNFT_EpxirationDateTooEarly(
    uint256 expirationTime,
    uint256 currentBlockTime
);
error NamefiNFT_ServiceCreditContractNotSet();
error NamefiNFT_ServiceCreditFailToCharge();
error NamefiNFT_TransferUnauthorized(
    address by,
    address from,
    address to,
    uint256 tokenId
);
error NamefiNFT_SignerUnauthorized(address signer, uint256 tokenId);
error NamefiNFT_URIQueryForNonexistentToken();
error NamefiNFT_ExtendTimeNotMultipleOf365Days();

/** 
 * @custom:security-contact security@d3serve.xyz
 * @custom:version V1.2.0
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
    "function setServiceCreditContract(address addr) public"
]
```
*/
contract NamefiNFT is
    Initializable,
    ERC721Upgradeable,
    AccessControlUpgradeable,
    ExpirableNFT,
    LockableNFT,
    EIP712Decoder,
    IERC5267Upgradeable
{
    string private _baseUriStr; // Storage Slot
    mapping(uint256 id => string) private _idToDomainNameMap; //  Storage Slot
    IChargeableERC20 public _NamefiServiceCreditContract; // Storage Slot

    // Currently MINTER_ROLE is used for minting, burning and updating expiration time
    // until we have need more fine-grain control.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    string public constant CONTRACT_NAME = "NamefiNFT";
    string public constant CONTRACT_SYMBOL = "NFNFT";
    string public constant CURRENT_VERSION = "v1.2.0";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // This is a URI for the contract itself. It is not a tokenURI.
    // It follows https://docs.opensea.io/docs/contract-level-metadata
    function contractURI() public pure returns (string memory) {
        return "https://md.namefi.io/namefi-nft.json";
    }

    function initialize() public initializer {
        __ERC721_init(CONTRACT_NAME, CONTRACT_SYMBOL);
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _baseUriStr = "https://md.namefi.io/";
    }

    function idToNormalizedDomainName(
        uint256 tokenId
    ) public view returns (string memory) {
        return _idToDomainNameMap[tokenId];
    }

    // if domainName contains any letter other than lowercase letters, numbers and ".", it is not normalized
    // in our normalized form it doens't end with "."
    // The following can be summarized as regex of /^[a-z0-9][a-z0-9\-\.]{1,253}\.$/
    // https://regex101.com/r/Sn1S3J/1
    function isNormalizedName(
        string memory domainName
    ) public pure returns (bool) {
        if (bytes(domainName).length < 3 || bytes(domainName).length > 255) {
            return false;
        }

        // A normalized domain name must NOT end with "."
        if (bytes(domainName)[bytes(domainName).length - 1] == ".") {
            return true;
        }

        // A nomralized domain name must start with lower case letter or number
        bytes1 firstChar = bytes(domainName)[0];
        if (
            firstChar < 0x30 ||
            (firstChar > 0x39 && firstChar < 0x61) ||
            firstChar > 0x7a
        ) {
            return false;
        }

        // if domainName contains any letter other than lowercase letters, numbers, dash and ".", it is not normalized
        for (uint i = 1; i < bytes(domainName).length - 2; i++) {
            bytes1 char = bytes(domainName)[i];
            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x61 && char <= 0x7a) && // a-z
                char != 0x2e && // "."
                char != 0x2d // "-"
            ) {
                return false;
            }
        }

        return true;
    }

    function normalizedDomainNameToId(
        string memory domainName
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(domainName)));
    }

    function _safeMintByName(
        address to,
        string memory domainName,
        uint256 expirationTime // same unit of block.timestamp
    ) internal virtual onlyRole(MINTER_ROLE) {
        if (!isNormalizedName(domainName))
            revert NamefiNFT_DomainNameNotNomalized(domainName);
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = domainName;
        if (expirationTime <= block.timestamp) {
            revert NamefiNFT_EpxirationDateTooEarly(
                expirationTime,
                block.timestamp
            );
        }
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

    function _ensureChargeServiceCredit(
        address chargee,
        uint256 chageAmount,
        string memory reason,
        bytes memory /* extraData */
    ) internal {
        if (_NamefiServiceCreditContract == IChargeableERC20(address(0))) {
            revert NamefiNFT_ServiceCreditContractNotSet();
        }
        // TODO: audit to protect from reentry attack
        bytes32 result = _NamefiServiceCreditContract.charge(
            address(this),
            chargee,
            chageAmount,
            // add string reason "NamefiNFT: mint" + domainName in one string
            reason,
            bytes("")
        );
        if (result != keccak256("SUCCESS")) {
            revert NamefiNFT_ServiceCreditFailToCharge();
        }
    }

    // DEPRECATED. TODO: remove after migration.
    function safeMintByNameWithCharge(
        address to,
        string memory domainName,
        uint256 expirationTime, // same unit of block.timestamp
        address chargee,
        bytes memory /*extraData*/
    ) external virtual onlyRole(MINTER_ROLE) {
        _ensureChargeServiceCredit(
            chargee,
            20e18, // HARDCODE for now. TODO: remove after migration.
            string(abi.encodePacked("NamefiNFT: mint ", domainName)),
            bytes("")
        );
        _safeMintByName(to, domainName, expirationTime);
    }

    function safeMintByNameWithChargeAmount(
        address to,
        string memory domainName,
        uint256 expirationTime, // same unit of block.timestamp
        address chargee,
        uint256 chargeAmount,
        bytes memory /*extraData*/
    ) external virtual onlyRole(MINTER_ROLE) {
        _ensureChargeServiceCredit(
            chargee,
            chargeAmount, // HARDCODE for now. TODO: remove after migration.
            string(abi.encodePacked("NamefiNFT: mint ", domainName)),
            bytes("")
        );
        _safeMintByName(to, domainName, expirationTime);
    }

    function burnByName(
        string memory domainName
    )
        public
        onlyRole(MINTER_ROLE)
        whenLocked(normalizedDomainNameToId(domainName), bytes(""))
    {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = "";
        _burn(tokenId);
    }

    function safeTransferFromByName(
        address from,
        address to,
        string memory domainName
    ) public {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) {
            revert NamefiNFT_TransferUnauthorized(
                _msgSender(),
                from,
                to,
                tokenId
            );
        }
        _idToDomainNameMap[tokenId] = domainName;
        _safeTransfer(from, to, tokenId, "");
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        virtual
        override
        whenNotLocked(tokenId, bytes(""))
        whenNotExpired(tokenId)
    {
        super._transfer(from, to, tokenId);
    }

    // URI
    function _baseURI() internal view override returns (string memory) {
        return _baseUriStr;
    }

    function setBaseURI(
        string memory baseUriStr
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseUriStr = baseUriStr;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (!_exists(tokenId)) {
            revert NamefiNFT_URIQueryForNonexistentToken();
        }
        return
            string(abi.encodePacked(_baseURI(), _idToDomainNameMap[tokenId]));
    }

    function setExpiration(
        uint256 tokenId,
        uint256 expirationTime
    ) public override onlyRole(MINTER_ROLE) {
        _setExpiration(tokenId, expirationTime);
    }

    // DEPRECATED TODO: remove after migration
    function extendByNameWithCharge(
        string memory domainName,
        uint256 timeToExtend, // Same unit with expirationTime new expiration time shall be expirationTime + timeToExtend
        address chargee,
        bytes memory /* extraEata */
    ) external virtual onlyRole(MINTER_ROLE) {
        if (timeToExtend % 365 days != 0) {
            revert NamefiNFT_ExtendTimeNotMultipleOf365Days();
        }
        uint256 yearToExtend = timeToExtend / 365 days;
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _ensureChargeServiceCredit(
            chargee,
            // For simplecity we are using a per-year model.
            20e18 * (yearToExtend),
            string(abi.encodePacked("NamefiNFT: mint ", domainName)),
            bytes("")
        );
        _setExpiration(tokenId, _getExpiration(tokenId) + timeToExtend);
    }

    function extendByNameWithChargeAmount(
        string memory domainName,
        uint256 timeToExtend, // Same unit with expirationTime new expiration time shall be expirationTime + timeToExtend
        address chargee,
        uint256 chargeAmount,
        bytes memory /* extraEata */
    ) external virtual onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _ensureChargeServiceCredit(
            chargee,
            chargeAmount,
            string(abi.encodePacked("NamefiNFT: mint ", domainName)),
            bytes("")
        );
        _setExpiration(tokenId, _getExpiration(tokenId) + timeToExtend);
    }

    function lock(
        uint256 tokenId,
        bytes calldata extra
    ) external payable override onlyRole(MINTER_ROLE) {
        _lock(tokenId, extra);
    }
    function lockByName(
        string memory domainName
    ) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _lock(tokenId, bytes(""));
    }

    function unlock(
        uint256 tokenId,
        bytes calldata extra
    ) external payable override onlyRole(MINTER_ROLE) {
        _unlock(tokenId, extra);
    }

    function unlockByName(
        string memory domainName
    ) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _unlock(tokenId, bytes(""));
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            super.supportsInterface(interfaceId) ||
            interfaceId == type(IERC5267Upgradeable).interfaceId;
    }

    function setServiceCreditContract(
        address addr
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _NamefiServiceCreditContract = IChargeableERC20(addr);
    }

    function getDomainHash() public view virtual override returns (bytes32) {
        EIP712Domain memory _input;
        _input.name = CONTRACT_NAME;
        _input.version = CURRENT_VERSION;
        _input.chainId = block.chainid;
        _input.verifyingContract = address(this);
        return getEip712DomainPacketHash(_input);
    }

    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f", // 01111
            CONTRACT_NAME,
            CURRENT_VERSION,
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    bytes32 public constant VALID_SIG_BY_ID_MAGIC_VALUE =
        keccak256("VALID_SIG_BY_ID_MAGIC_VALUE");
    bytes32 public constant VALID_SIG_BY_ID_BAD_VALUE =
        keccak256("VALID_SIG_BY_ID_BAD_VALUE");
    function _isValidSignatureByTokenId(
        uint256 tokenId,
        address signer,
        bytes32 digest,
        bytes memory siganture,
        bytes memory /*extraData*/
    ) internal view returns (bytes32 magicValue) {
        if (!_exists(tokenId)) {
            revert NamefiNFT_URIQueryForNonexistentToken();
        }
        if (!_isApprovedOrOwner(signer, tokenId)) {
            revert NamefiNFT_SignerUnauthorized(signer, tokenId);
        }
        if (
            SignatureCheckerUpgradeable.isValidSignatureNow(
                signer,
                digest,
                siganture
            )
        ) {
            return VALID_SIG_BY_ID_MAGIC_VALUE;
        } else {
            return VALID_SIG_BY_ID_BAD_VALUE;
        }
    }

    function isValidSignatureByTokenId(
        uint256 tokenId,
        address signer,
        bytes32 digest,
        bytes memory siganture,
        bytes calldata /*extraData*/
    ) external view returns (bytes32 magicValue) {
        return
            _isValidSignatureByTokenId(
                tokenId,
                signer,
                digest,
                siganture,
                bytes("")
            );
    }

    function isValidSignatureByName(
        string memory name,
        address signer,
        bytes32 digest,
        bytes memory siganture,
        bytes calldata /*extraData*/
    ) external view returns (bytes32 magicValue) {
        uint256 id = normalizedDomainNameToId(name);
        return
            _isValidSignatureByTokenId(
                id,
                signer,
                digest,
                siganture,
                bytes("")
            );
    }
}
