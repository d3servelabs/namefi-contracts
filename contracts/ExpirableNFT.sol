// SPDX-License-Identifier: Apache-2.0+
// Author: Team Namefi by D3ServeLabs
// https://namefi.io
// https://d3serve.xyz
// Security Contact: security@d3serve.xyz

pragma solidity ^0.8.20;

// ExpirableNFT: expired
error ExpirableNFT_Expired(uint256 tokenId);

/**
 * @title ExpirableNFT
 * @dev Abstract contract that adds expiration functionality to NFTs.
 * Tokens can have expiration times set, and operations can be restricted based on expiration status.
 * When a token expires, certain operations (like transfers) are automatically blocked.
 * 
 * Key features:
 * - Tokens have expiration timestamps
 * - Expired tokens cannot be transferred (via whenNotExpired modifier)
 * - Expiration can be extended or modified by authorized parties
 * - Emits events when expiration times change
 * 
 * This contract is designed to be inherited by NFT implementations that need time-based validity.
 */
abstract contract ExpirableNFT {
    /// @dev Mapping from token ID to expiration timestamp
    mapping(uint256 id => uint256) private _expirations;
    
    /**
     * @dev Event emitted when a token's expiration time is changed
     * @param tokenId The ID of the token whose expiration changed
     * @param newExpirationTime The new expiration timestamp
     */
    event ExpirationChanged(uint256 indexed tokenId, uint256 newExpirationTime);
    
    /**
     * @dev Internal function to get a token's expiration time
     * @param tokenId The token ID to query
     * @return The expiration timestamp (0 if not set)
     */
    function _getExpiration(uint256 tokenId) internal view returns (uint256) {
        return _expirations[tokenId];
    }
    
    /**
     * @notice Get the expiration time of a token
     * @dev Returns 0 if the token has no expiration set or doesn't exist
     * @param tokenId The token ID to query
     * @return The expiration timestamp
     */
    function getExpiration(uint256 tokenId) public view returns (uint256) {
        return _getExpiration(tokenId);
    }
    
    /**
     * @notice Check if a token is expired
     * @dev Returns false for non-existent tokens as well as valid tokens
     * @param tokenId The token to check
     * @return True if the token exists and is expired, false otherwise
     */
    function isExpired(uint256 tokenId) public view returns (bool) {
        return _isExpired(tokenId);
    }

    /**
     * @dev Internal function to set a token's expiration time
     * @param tokenId The token ID to set expiration for
     * @param expirationTime The new expiration timestamp
     * @dev Emits ExpirationChanged event
     */
    function _setExpiration(uint256 tokenId, uint256 expirationTime) internal {
        _expirations[tokenId] = expirationTime;
        emit ExpirationChanged(tokenId, expirationTime);
    }

    /**
     * @dev Internal function to check if a token is expired
     * @param tokenId The token ID to check
     * @return True if the token is expired (expiration time < current block timestamp)
     * @dev Returns true for tokens with expiration time of 0 or any past timestamp
     */
    function _isExpired(uint256 tokenId) internal view returns (bool) {
        return _expirations[tokenId] < block.timestamp;
    }

    /**
     * @dev Modifier that prevents execution if the token is expired
     * @param tokenId The token ID to check
     * @dev Reverts with ExpirableNFT_Expired if the token is expired
     */
    modifier whenNotExpired(uint256 tokenId) {
        if (_isExpired(tokenId)) revert ExpirableNFT_Expired(tokenId);
        _;
    }

    /**
     * @notice Set the expiration time for a token
     * @dev This is a virtual function that must be implemented by inheriting contracts
     * @dev Implementation should include appropriate access control
     * @param tokenId The token ID to set expiration for
     * @param expirationTime The new expiration timestamp
     */
    function setExpiration(uint256 tokenId, uint256 expirationTime) public virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}