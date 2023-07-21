// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "prb-math/contracts/PRBMathSD59x18.sol";
import "prb-math/contracts/PRBMath.sol";

/// @custom:security-contact contact@dkdk.club
contract ADonkeyDecay is ERC721, ERC721URIStorage, Ownable {
    using PRBMathSD59x18 for int256;
    using Counters for Counters.Counter;
    event UpdateTreasury(address indexed treasury);
    Counters.Counter private _tokenIdCounter;
    uint256 private _lastMintBlock;  // Default to 0
    string private _overrideBaseURI;
    address payable private _treasury;

    int256 public constant INITIAL_PRICE = 10 ether; // in Wei
    int256 public constant FINAL_PRICE = 0.001 ether; // in Wei
    int256 public constant AUCTION_DURATION_BLOCKS = (96 * 60 * 60 ) / 12 ; // Assume 12 seconds per block
    uint256 public constant MAX_SUPPLY = 1000;

    constructor(
        address initOwner,
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) {
        _transferOwnership(initOwner);
        _setBaseURI(baseURI);
        _treasury = payable(initOwner);
        _lastMintBlock = block.number;
    }

    // --- READONLY FUNCTIONS --- //
    function getLastMintBlock() public view returns (uint256) {
        return _lastMintBlock;
    }

    function getElapsedPortion(uint256 blockNum) public view returns (int256) {
        int256 elapsedPortion;
        if (getElapsedTime(blockNum) > AUCTION_DURATION_BLOCKS) {
            elapsedPortion = 1e18;
        } else {
            elapsedPortion = getElapsedTime(blockNum).div(AUCTION_DURATION_BLOCKS);
        }
        return elapsedPortion;
    }

    function getElapsedTime(uint256 blockNum) public view returns (int256) {
        return int256(blockNum - _lastMintBlock);
    }

    function currentPrice() external view returns (int256) {
        return _getPriceAtBlock(block.number);
    }

    function getPriceAtBlock(uint256 blockNum) external view returns (int256) {
        return _getPriceAtBlock(blockNum);
    }

    function _getPriceAtBlock(uint256 blockNum) internal view returns (int256) {
        int256 base = FINAL_PRICE.div(INITIAL_PRICE);
        return INITIAL_PRICE.mul(base.pow(getElapsedPortion(blockNum)));
    }

    function _baseURI() internal view override returns (string memory) {
        return bytes(_overrideBaseURI).length > 0 ? _overrideBaseURI : super._baseURI();
    }

    // --- WRAPPER OF WRITE FUNCTIONS  --- //
    fallback() external payable {
        _safeMint(msg.sender);
    }

    receive() external payable {
        _safeMint(msg.sender);
    }

    function safeMint(address to) public payable { 
        require(_tokenIdCounter.current() < MAX_SUPPLY, "Max supply reached");
        _safeMint(to);
    }
    
    // --- CORE WRITE FUNCTIONS  --- //

    function _safeMint(address to) internal {
        // assert the payment has enough value
        uint256 price = uint256(_getPriceAtBlock(block.number));
        require(msg.value >= price, "Not enough value sent");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        // refund the excess value sent
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        _lastMintBlock = block.number;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }
    
    function _setBaseURI(string memory baseURI) internal {
        _overrideBaseURI = baseURI;
    }

    function setTreasury(address payable treasury) public onlyOwner {
        _treasury = treasury;
    }

    function getTreasury() public view returns (address payable) {
        return _treasury;
    }

    /// @dev Withdraws all proceeds to the treasury address
    function withdrawProceeds() public {
        require(_treasury != address(0), "Treasury not set");
        require(address(this).balance > 0, "No proceeds to withdraw");
        require(msg.sender == _treasury || msg.sender == owner(), "Not authorized");
        payable(_treasury).transfer(address(this).balance);
    }


    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
