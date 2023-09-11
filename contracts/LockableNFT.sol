// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

abstract contract LockableNFT {
    mapping(uint256 id => bool) private _locks;
    
    event Lock(uint256 indexed tokenId);
    event Unlock(uint256 indexed tokenId);

    function isLocked(uint256 tokenId) public view returns (bool) {
        return _locks[tokenId];
    }

    function _lock(uint256 tokenId) internal {
        _locks[tokenId] = true;
    }

    function _unlock(uint256 tokenId) internal {
        _locks[tokenId] = false;
    }
}