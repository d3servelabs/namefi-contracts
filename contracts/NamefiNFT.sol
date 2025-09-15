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

// TODO: typo: should be NamefiNFT_DomainNameNotNormalized
error NamefiNFT_DomainNameNotNomalized(string domainName);
// TODO: typo: should be NamefiNFT_ExpirationDateTooEarly
error NamefiNFT_EpxirationDateTooEarly(uint256 expirationTime, uint256 currentBlockTime);
error NamefiNFT_ServiceCreditContractNotSet();
error NamefiNFT_ServiceCreditFailToCharge();
error NamefiNFT_TransferUnauthorized(address by, address from, address to, uint256 tokenId);
error NamefiNFT_SignerUnauthorized(address signer, uint256 tokenId);
error NamefiNFT_URIQueryForNonexistentToken();
error NamefiNFT_ExtendTimeNotMultipleOf365Days();

/** 
 * @custom:security-contact security@d3serve.xyz
 * @custom:version V1.4.0-rc1
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
        IERC5267Upgradeable {
    string private _baseUriStr;  // Storage Slot
    mapping(uint256 id => string) private _idToDomainNameMap; //  Storage Slot
    IChargeableERC20 public _NamefiServiceCreditContract;  // Storage Slot

    // Currently MINTER_ROLE is used for minting, burning and updating expiration time
    // until we have need more fine-grain control.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    string public constant CONTRACT_NAME = "NamefiNFT";
    string public constant CONTRACT_SYMBOL = "NFNFT";
    string public constant CURRENT_VERSION = "V1.4.0-rc1";
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // This is a URI for the contract itself. It is not a tokenURI.
    // It follows https://docs.opensea.io/docs/contract-level-metadata
    function contractURI() public pure returns (string memory) {
        return "https://md.namefi.io/namefi-nft.json";
    }

    function initialize() initializer public {
        __ERC721_init(CONTRACT_NAME, CONTRACT_SYMBOL);
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _baseUriStr = "https://md.namefi.io/";
    }

    function idToNormalizedDomainName(uint256 tokenId) public view returns (string memory) {
        return _idToDomainNameMap[tokenId];
    }

    // Check if the first character is valid (lowercase letter or number)
    function _ensureValidFirstChar(string memory domainName) internal pure returns (bool) {
        if (bytes(domainName).length == 0) {
            return false;
        }
        bytes1 firstChar = bytes(domainName)[0];
        // First char must be lowercase letter (a-z) or number (0-9)
        return firstChar >= 0x30 && firstChar <= 0x39 // 0-9
            || firstChar >= 0x61 && firstChar <= 0x7a; // a-z
    }

    // Check if the last character is valid (lowercase letter or number, not dot or dash)
    function _ensureValidLastChar(string memory domainName) internal pure returns (bool) {
        if (bytes(domainName).length == 0) {
            return false;
        }
        bytes1 lastChar = bytes(domainName)[bytes(domainName).length - 1];
        // Last char must be lowercase letter (a-z) or number (0-9)
        // Cannot be dot (.) or dash (-) per ICANN rules
        return lastChar >= 0x30 && lastChar <= 0x39 // 0-9
            || lastChar >= 0x61 && lastChar <= 0x7a; // a-z
    }

    // if domainName contains any letter other than lowercase letters, numbers, dash and ".", it is not normalized
    function _ensureLdh(string memory domainName) internal pure returns (bool) {
        for (uint i = 1; i < bytes(domainName).length - 2; i++) {
            bytes1 char = bytes(domainName)[i];
            if (
                !(char >= 0x30 && char <= 0x39) // 0-9
                && !(char >= 0x61 && char <= 0x7a)  // a-z
                && char != 0x2e // "."
                && char != 0x2d // "-"
            ) {
                return false;
            }
        }
        return true;
    }

    function _ensureLabelLength(string memory domainName) internal pure returns (bool) {
        // for each label, it must be 1-63 characters long
        uint256 labelLength = 0;
        for (uint i = 0; i < bytes(domainName).length; i++) {
            bytes1 char = bytes(domainName)[i];
            if (char == 0x2e) { // "."
                // Check if previous label length is valid (1-63 chars)
                if (labelLength == 0 || labelLength > 63) {
                    return false;
                }
                // Reset counter for next label
                labelLength = 0;
            } else {
                // Not a dot, increment the label length
                labelLength++;
            }
        }
        
        // // Check the last label (after the last dot)
        if (labelLength == 0 || labelLength > 63) {
            return false;
        }
        return true;
    }

    // if domainName contains any letter other than lowercase letters, numbers and ".", it is not normalized
    // in our normalized form it doens't end with "."
    // The following can be summarized as regex of /^[a-z0-9][a-z0-9\-\.]{1,253}\.$/
    // https://regex101.com/r/Sn1S3J/1
    function isNormalizedName(string memory domainName) public pure returns (bool) {
        if (bytes(domainName).length < 3 || bytes(domainName).length > 255) {
            return false;
        }
    
        // A normalized domain name must NOT end with "."
        if (bytes(domainName)[bytes(domainName).length - 1] == ".") {
            return false;
        }

        // A normalized domain name must start with lower case letter or number
        if (!_ensureValidFirstChar(domainName)) {
            return false;
        }

        // Enable for ICANN compliance - this would be a breaking change
        // A normalized domain name must end with lower case letter or number (not dash or special chars)
        if (!_ensureValidLastChar(domainName)) {
            return false;
        }

        // if domainName contains any letter other than lowercase letters, numbers, dash and ".", it is not normalized
        if (!_ensureLdh(domainName)) {
            return false;
        }
        
        if (!_ensureLabelLength(domainName)) {
            return false;
        }
        return true;
    }
    

    function normalizedDomainNameToId(string memory domainName) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(domainName)));
    }

    function _safeMintByName(
        address to, 
        string memory domainName,
        uint256 expirationTime // same unit of block.timestamp
    ) internal virtual onlyRole(MINTER_ROLE) {
        if (!isNormalizedName(domainName)) revert NamefiNFT_DomainNameNotNomalized(domainName);
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _idToDomainNameMap[tokenId] = domainName;
        if (expirationTime <= block.timestamp) {
            revert NamefiNFT_EpxirationDateTooEarly(expirationTime, block.timestamp);
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
            bytes memory /* extraData */) internal {
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
            bytes(""));
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
            bytes(""));
        _safeMintByName(to, domainName, expirationTime);
    }

    /**
     * @notice Burns a token by its domain name
     * @dev The token must be locked before it can be burned.
     * Unlike the ERC721 burn operation, this function preserves the domain name mapping
     * so that idToNormalizedDomainName still returns the original domain name after burning.
     * This allows for historical record keeping and prevents domain name data loss.
     * @param domainName The domain name of the token to burn
     */
    function burnByName(string memory domainName) public 
        onlyRole(MINTER_ROLE)
        whenLocked(normalizedDomainNameToId(domainName), bytes("")) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        // Domain name mapping is intentionally preserved for historical reference
        // Removing the next line to preserve the mapping
        // _idToDomainNameMap[tokenId] = "";
        _burn(tokenId);
    }

    /**
     * @notice Transfer a token using domain name instead of token ID
     * @dev This function converts a domain name to a token ID and then performs a transfer
     * The function will succeed if the token is not expired at the time of the call.
     * There is no check to prevent transfers of tokens that are about to expire.
     * @param from Current owner of the token
     * @param to Address to receive the token
     * @param domainName The domain name of the token to transfer
     */
    function safeTransferFromByName(address from, address to, string memory domainName) public {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) {
            revert NamefiNFT_TransferUnauthorized(_msgSender(), from, to, tokenId);
        }
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
        if (!_exists(tokenId)) {
            revert NamefiNFT_URIQueryForNonexistentToken();
        }
        return string(abi.encodePacked(_baseURI(), _idToDomainNameMap[tokenId]));
    }

    /**
     * @notice Set the expiration time for a token
     * @dev This function allows setting any expiration time, including past timestamps
     * which will immediately expire the token. This is an intentional design choice
     * to allow administrative control over token expiration.
     * Only accounts with MINTER_ROLE can call this function, not token owners.
     * No batch operations are supported to keep the contract simple.
     * @param tokenId The ID of the token to set expiration for
     * @param expirationTime The new expiration timestamp (can be in the past)
     */
    function setExpiration(uint256 tokenId, uint256 expirationTime) public override onlyRole(MINTER_ROLE) {
        _setExpiration(tokenId, expirationTime);
    }

    /**
     * @notice Set expiration by domain name instead of token ID
     * @dev Maps the domain name to a token ID and then sets the expiration
     * Same restrictions apply as setExpiration()
     * @param domainName The domain name of the token
     * @param expirationTime The new expiration timestamp
     */
    function setExpirationByName(string memory domainName, uint256 expirationTime) external onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _setExpiration(tokenId, expirationTime);
    }

    // DEPRECATED TODO: remove after migration
    function extendByNameWithCharge(
            string memory domainName, 
            uint256 timeToExtend, // Same unit with expirationTime new expiration time shall be expirationTime + timeToExtend
            address chargee,
            bytes memory /* extraEata */) external virtual onlyRole(MINTER_ROLE) {
        if (timeToExtend % 365 days != 0) {
            revert NamefiNFT_ExtendTimeNotMultipleOf365Days();
        }
        uint256 yearToExtend = timeToExtend / 365 days;
        uint256 tokenId = normalizedDomainNameToId(domainName);        
        _ensureChargeServiceCredit(
            chargee, 
            // For simplecity we are using a per-year model.
            20e18 * (yearToExtend),
            string(abi.encodePacked("NamefiNFT: extend ", domainName)),
            bytes(""));
         _setExpiration(tokenId, _getExpiration(tokenId) + timeToExtend);
    }

    /**
     * @notice Extend the expiration of a token by domain name with specified charge amount
     * @dev This function adds the specified duration to the current expiration time
     * The function intentionally accepts any duration value without normalization.
     * Only accounts with MINTER_ROLE can call this function, not token owners.
     * There is no emergency override mechanism for expired tokens.
     * @param domainName The domain name of the token to extend
     * @param timeToExtend The duration to add to the current expiration time (in seconds)
     * @param chargee The account to charge for the extension
     * @param chargeAmount The amount of tokens to charge
     * @param extraData Additional data for the transaction
     */
    function extendByNameWithChargeAmount(
        string memory domainName,
        uint256 timeToExtend, // Same unit with expirationTime new expiration time shall be expirationTime + timeToExtend
        address chargee,
        uint256 chargeAmount,
        bytes memory extraData) external virtual onlyRole(MINTER_ROLE) {
        uint256 tokenId = normalizedDomainNameToId(domainName);
        _ensureChargeServiceCredit(
            chargee, 
            chargeAmount, 
            string(abi.encodePacked("NamefiNFT: extend ", domainName)),
            bytes(""));
        _setExpiration(tokenId, _getExpiration(tokenId) + timeToExtend);
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
        return super.supportsInterface(interfaceId) 
            || interfaceId == type(IERC5267Upgradeable).interfaceId;
    }

    function setServiceCreditContract(address addr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _NamefiServiceCreditContract = IChargeableERC20(addr);
    }

    function getDomainHash() public view override virtual returns (bytes32) {
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
        ) {
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

    bytes32 public constant VALID_SIG_BY_ID_MAGIC_VALUE = keccak256("VALID_SIG_BY_ID_MAGIC_VALUE");
    bytes32 public constant VALID_SIG_BY_ID_BAD_VALUE = keccak256("VALID_SIG_BY_ID_BAD_VALUE");
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
        if (SignatureCheckerUpgradeable.isValidSignatureNow(signer, digest, siganture)) {
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
        return _isValidSignatureByTokenId(tokenId, signer, digest, siganture, bytes(""));
    }

    function isValidSignatureByName(
        string memory name,
        address signer,
        bytes32 digest,
        bytes memory siganture,
        bytes calldata /*extraData*/
    ) external view returns (bytes32 magicValue) {
        uint256 id = normalizedDomainNameToId(name);
        return _isValidSignatureByTokenId(id, signer, digest, siganture, bytes(""));
    }

}