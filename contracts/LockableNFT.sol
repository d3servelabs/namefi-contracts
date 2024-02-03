// SPDX-License-Identifier: Apache-2.0+
// Author: Team Namefi by D3ServeLabs
// https://namefi.io
// https://d3serve.xyz
// Security Contact: security@d3serve.xyz

pragma solidity ^0.8.20;

error LockableNFT_Locked(uint256 tokenId);
error LockableNFT_NotLocked(uint256 tokenId);

/** 
 * The ABI of this interface in javascript array such as
```
[
    "function isLocked(uint256 tokenId) external view returns (bool)",
    "function isLocked(uint256 tokenId, bytes calldata extra) external view returns (bool)",
    "function lock(uint256 tokenId, bytes memory extra) external payable virtual",
    "function unlock(uint256 tokenId, bytes memory extra) external payable virtual",
    "event Lock(uint256 indexed tokenId, bytes extra)",
    "event Unlock(uint256 indexed tokenId, bytes extra)"
]
```
*/
abstract contract LockableNFT {
    mapping(uint256 id => bool) private _locks;
    
    event Lock(uint256 indexed tokenId, bytes extra);
    event Unlock(uint256 indexed tokenId, bytes extra);

    function isLocked(uint256 tokenId) external view returns (bool) {
        return _isLocked(tokenId, bytes(""));
    }

    function isLocked(uint256 tokenId, bytes calldata extra) external view returns (bool) {
        return _isLocked(tokenId, extra);
    }

    function _isLocked(uint256 tokenId, bytes memory /*extra*/) internal view returns (bool) {
        return _locks[tokenId];
    }

    function _lock(uint256 tokenId, bytes memory extra) internal {
        _locks[tokenId] = true;
        emit Lock(tokenId, extra);
    }

    function _unlock(uint256 tokenId, bytes memory extra) internal {
        _locks[tokenId] = false;
        emit Unlock(tokenId, extra);
    }

    function lock(uint256 tokenId, bytes memory extra) external payable virtual;
    function unlock(uint256 tokenId, bytes memory extra) external payable virtual;

    modifier whenNotLocked (uint256 tokenId, bytes memory /*extra*/) {
        if (_locks[tokenId]) revert LockableNFT_Locked(tokenId);
        _;
    }
    
    modifier whenLocked (uint256 tokenId, bytes memory /*extra*/) {
        if (!_locks[tokenId]) revert LockableNFT_NotLocked(tokenId);
        _;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
