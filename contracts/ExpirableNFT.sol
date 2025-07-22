// SPDX-License-Identifier: Apache-2.0+
// Author: Team Namefi by D3ServeLabs
// https://namefi.io
// https://d3serve.xyz
// Security Contact: security@d3serve.xyz

pragma solidity ^0.8.20;

// ExpirableNFT: expired
error ExpirableNFT_Expired(uint256 tokenId);

abstract contract ExpirableNFT {
    mapping(uint256 id => uint256) private _expirations;
    
    // Event emitted when token expiration is changed
    event ExpirationChanged(uint256 indexed tokenId, uint256 newExpirationTime);
    
    function _getExpiration(uint256 tokenId) internal view returns (uint256) {
        return _expirations[tokenId];
    }
    
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

    function _setExpiration(uint256 tokenId, uint256 expirationTime) internal {
        _expirations[tokenId] = expirationTime;
        emit ExpirationChanged(tokenId, expirationTime);
    }

    function _isExpired(uint256 tokenId) internal view returns (bool) {
        return _expirations[tokenId] < block.timestamp;
    }

    modifier whenNotExpired(uint256 tokenId) {
        if (_isExpired(tokenId)) revert ExpirableNFT_Expired(tokenId);
        _;
    }

    function setExpiration(uint256 tokenId, uint256 expirationTime) public virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}