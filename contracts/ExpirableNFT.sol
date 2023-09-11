// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

abstract contract ExpirableNFT {
    mapping(uint256 id => uint256) private _expirations;

    function getExpiration(uint256 tokenId) public view returns (uint256) {
        return _expirations[tokenId];
    }
    
    function isExpired(uint256 tokenId) public view returns (bool) {
        return _isExpired(tokenId);
    }

    function _setExpiration(uint256 tokenId, uint256 expirationTime) internal {
        _expirations[tokenId] = expirationTime;
    }

    function _isExpired(uint256 tokenId) internal view returns (bool) {
        return _expirations[tokenId] < block.timestamp;
    }

    modifier notExpired(uint256 tokenId) {
        require(!_isExpired(tokenId), "ExpirableNFT: expired");
        _;
    }

    function setExpiration(uint256 tokenId, uint256 expirationTime) public virtual;
}