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

    modifier whenNotLocked (uint256 tokenId) {
        require(!_locks[tokenId], "LockableNFT: locked");
        _;
    }
    
    modifier whenLocked (uint256 tokenId) {
        require(_locks[tokenId], "LockableNFT: not locked");
        _;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}