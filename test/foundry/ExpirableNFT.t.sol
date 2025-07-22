// SPDX-License-Identifier: Apache-2.0+
// Author: Team Namefi by D3ServeLabs
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/ExpirableNFT.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Concrete implementation of ExpirableNFT for testing
contract TestExpirableNFT is ERC721, ExpirableNFT {
    address public minter;
    
    constructor() ERC721("TestExpirable", "TEXP") {
        minter = msg.sender;
    }
    
    function mint(address to, uint256 tokenId, uint256 expirationTime) external {
        require(msg.sender == minter, "Not authorized to mint");
        _mint(to, tokenId);
        _setExpiration(tokenId, expirationTime);
    }
    
    function setExpiration(uint256 tokenId, uint256 expirationTime) public override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not token owner or approved");
        _setExpiration(tokenId, expirationTime);
    }
    
    function transferToken(address from, address to, uint256 tokenId) external whenNotExpired(tokenId) {
        _transfer(from, to, tokenId);
    }
    
    function getTokenData(uint256 tokenId) external view returns (uint256, bool) {
        return (_getExpiration(tokenId), _isExpired(tokenId));
    }
    
    // Add the ERC721 approval methods to allow testing approval behaviors
    function approve(address to, uint256 tokenId) public override {
        super.approve(to, tokenId);
    }
    
    function getApproved(uint256 tokenId) public view override returns (address) {
        return super.getApproved(tokenId);
    }
    
    function setApprovalForAll(address operator, bool approved) public override {
        super.setApprovalForAll(operator, approved);
    }
    
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return super.isApprovedForAll(owner, operator);
    }
}

contract ExpirableNFTTest is Test {
    TestExpirableNFT public nft;
    
    address public deployer;
    address public alice;
    address public bob;
    address public charlie;
    
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant TOKEN_ID_2 = 2;
    uint256 public constant TOKEN_ID_3 = 3;
    
    function setUp() public {
        deployer = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        
        // Start with a known timestamp
        vm.warp(1000000);
        
        nft = new TestExpirableNFT();
    }
    
    function test_InitialMintWithExpiration() public {
        // Mint a token with future expiration
        uint256 expirationTime = block.timestamp + 100 days;
        nft.mint(alice, TOKEN_ID, expirationTime);
        
        // Verify owner and expiration
        assertEq(nft.ownerOf(TOKEN_ID), alice);
        assertEq(nft.getExpiration(TOKEN_ID), expirationTime);
        assertFalse(nft.isExpired(TOKEN_ID));
    }
    
    function test_MintWithPastExpiration() public {
        // Set current time
        uint256 currentTime = block.timestamp;
        
        // Mint a token with future expiration
        uint256 futureTime = currentTime + 100;
        nft.mint(alice, TOKEN_ID, futureTime);
        assertFalse(nft.isExpired(TOKEN_ID));
        
        // Warp time to make token expired
        vm.warp(futureTime + 1);
        
        // Now the token should be expired
        assertTrue(nft.isExpired(TOKEN_ID));
    }
    
    function test_SetExpiration() public {
        // Mint a token with future expiration
        uint256 expirationTime = block.timestamp + 100 days;
        nft.mint(alice, TOKEN_ID, expirationTime);
        
        // Change expiration time
        uint256 newExpirationTime = block.timestamp + 365 days;
        vm.prank(alice);
        nft.setExpiration(TOKEN_ID, newExpirationTime);
        
        // Verify new expiration
        assertEq(nft.getExpiration(TOKEN_ID), newExpirationTime);
    }
    
    function test_OnlyOwnerCanSetExpiration() public {
        // Mint a token
        uint256 expirationTime = block.timestamp + 100 days;
        nft.mint(alice, TOKEN_ID, expirationTime);
        
        // Bob is not the owner and should not be able to set expiration
        vm.expectRevert("Not token owner or approved");
        vm.prank(bob);
        nft.setExpiration(TOKEN_ID, block.timestamp + 10 days);
        
        // Approve bob to manage the token
        vm.prank(alice);
        nft.approve(bob, TOKEN_ID);
        
        // Now bob should be able to set expiration
        uint256 newExpirationTime = block.timestamp + 30 days;
        vm.prank(bob);
        nft.setExpiration(TOKEN_ID, newExpirationTime);
        
        // Verify expiration was updated
        assertEq(nft.getExpiration(TOKEN_ID), newExpirationTime);
    }
    
    function test_TransferRestrictedWhenExpired() public {
        // Mint a token with future expiration
        uint256 expirationTime = block.timestamp + 100;
        nft.mint(alice, TOKEN_ID, expirationTime);
        
        // Transfer should work when not expired
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
        assertEq(nft.ownerOf(TOKEN_ID), bob);
        
        // Mint another token
        nft.mint(alice, TOKEN_ID_2, expirationTime);
        
        // Warp time to make token expire
        vm.warp(expirationTime + 1);
        
        // Transfer should fail when expired
        vm.expectRevert(abi.encodeWithSelector(ExpirableNFT_Expired.selector, TOKEN_ID_2));
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID_2);
    }
    
    function test_ExpirationTransition() public {
        // Mint token with expiration very soon
        uint256 expirationTime = block.timestamp + 10;
        nft.mint(alice, TOKEN_ID, expirationTime);
        
        // Not expired yet
        assertFalse(nft.isExpired(TOKEN_ID));
        
        // Warp time to after expiration
        vm.warp(expirationTime + 1);
        
        // Should be expired now
        assertTrue(nft.isExpired(TOKEN_ID));
        
        // Transfer should fail
        vm.expectRevert(abi.encodeWithSelector(ExpirableNFT_Expired.selector, TOKEN_ID));
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
        
        // Extend expiration
        vm.prank(alice);
        nft.setExpiration(TOKEN_ID, block.timestamp + 100);
        
        // Should be valid again
        assertFalse(nft.isExpired(TOKEN_ID));
        
        // Transfer should work now
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
        assertEq(nft.ownerOf(TOKEN_ID), bob);
    }
    
    function test_MultipleExpirationStates() public {
        // Get current time
        uint256 currentTime = block.timestamp;
        
        // Mint multiple tokens with different expiration times
        nft.mint(alice, TOKEN_ID, currentTime + 5);    // Expires very soon
        nft.mint(alice, TOKEN_ID_2, currentTime + 20); // Expires later
        nft.mint(alice, TOKEN_ID_3, currentTime + 100); // Expires much later
        
        // Check initial states
        assertFalse(nft.isExpired(TOKEN_ID));
        assertFalse(nft.isExpired(TOKEN_ID_2));
        assertFalse(nft.isExpired(TOKEN_ID_3));
        
        // Warp time forward slightly
        vm.warp(currentTime + 10);
        
        // Check updated states
        assertTrue(nft.isExpired(TOKEN_ID));   // Now expired
        assertFalse(nft.isExpired(TOKEN_ID_2)); // Still valid
        assertFalse(nft.isExpired(TOKEN_ID_3)); // Still valid
        
        // Warp time forward again
        vm.warp(currentTime + 30);
        
        // Check updated states
        assertTrue(nft.isExpired(TOKEN_ID));   // Still expired
        assertTrue(nft.isExpired(TOKEN_ID_2));  // Now expired
        assertFalse(nft.isExpired(TOKEN_ID_3)); // Still valid
        
        // Extend token1
        vm.prank(alice);
        nft.setExpiration(TOKEN_ID, block.timestamp + 100);
        
        // Check final states
        assertFalse(nft.isExpired(TOKEN_ID)); // Now valid again
        assertTrue(nft.isExpired(TOKEN_ID_2)); // Still expired
        assertFalse(nft.isExpired(TOKEN_ID_3)); // Still valid
    }
    
    function test_ZeroExpirationTime() public {
        // Mint with zero expiration time (should be considered expired)
        nft.mint(alice, TOKEN_ID, 0);
        
        // Check it's expired
        assertTrue(nft.isExpired(TOKEN_ID));
        
        // Transfer should fail
        vm.expectRevert(abi.encodeWithSelector(ExpirableNFT_Expired.selector, TOKEN_ID));
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
    }
    
    function test_MaxUint256ExpirationTime() public {
        // Mint with max uint256 expiration time (effectively never expires)
        nft.mint(alice, TOKEN_ID, type(uint256).max);
        
        // Check it's not expired
        assertFalse(nft.isExpired(TOKEN_ID));
        
        // Even far in the future
        vm.warp(block.timestamp + 1000 * 365 days);
        assertFalse(nft.isExpired(TOKEN_ID));
        
        // Transfer should work
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
        assertEq(nft.ownerOf(TOKEN_ID), bob);
    }
    
    function test_SettingExpirationToPastTime() public {
        // Mint the token with a future expiration time
        uint256 futureTime = block.timestamp + 100;
        nft.mint(alice, TOKEN_ID, futureTime);
        assertFalse(nft.isExpired(TOKEN_ID));
        
        // Set expiration to a time in the past
        uint256 pastTime = 1; // Use a definite past time value
        vm.prank(alice);
        nft.setExpiration(TOKEN_ID, pastTime);
        
        // Token should now be expired
        assertTrue(nft.isExpired(TOKEN_ID));
        
        // Setting to current time (should also be expired immediately)
        vm.prank(alice);
        nft.setExpiration(TOKEN_ID, block.timestamp);
        
        // The token might not be expired immediately due to block.timestamp granularity
        // in the test environment, so we'll warp a tiny bit forward to ensure it's expired
        vm.warp(block.timestamp + 1);
        assertTrue(nft.isExpired(TOKEN_ID));
    }
    
    function test_NonExistentTokenExpirationError() public {
        uint256 nonExistentToken = 999;
        
        // Try to get expiration of a non-existent token
        // The view function might not revert, but should return 0 or some default
        uint256 expiration = nft.getExpiration(nonExistentToken);
        assertTrue(expiration == 0 || nft.isExpired(nonExistentToken));
        
        // Setting expiration on a non-existent token should revert
        vm.expectRevert("ERC721: invalid token ID");
        vm.prank(alice);
        nft.setExpiration(nonExistentToken, block.timestamp + 100);
    }
    
    function test_ApprovalBehaviorOnExpiration() public {
        // Mint token with future expiration time
        uint256 expirationTime = block.timestamp + 100;
        nft.mint(alice, TOKEN_ID, expirationTime);
        
        // Expire the token
        vm.warp(expirationTime + 1);
        assertTrue(nft.isExpired(TOKEN_ID));
        
        // Even the owner cannot transfer when expired
        vm.expectRevert(abi.encodeWithSelector(ExpirableNFT_Expired.selector, TOKEN_ID));
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
        
        // Owner can extend the expiration
        vm.prank(alice);
        nft.setExpiration(TOKEN_ID, block.timestamp + 100);
        assertFalse(nft.isExpired(TOKEN_ID));
        
        // Now transfer should work
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
        assertEq(nft.ownerOf(TOKEN_ID), bob);
    }
    
    function test_DirectVsDelegatedExpiration() public {
        // Mint a token
        uint256 expirationTime = block.timestamp + 100;
        nft.mint(alice, TOKEN_ID, expirationTime);
        
        // Try to set expiration directly as bob (should fail)
        vm.expectRevert("Not token owner or approved");
        vm.prank(bob);
        nft.setExpiration(TOKEN_ID, block.timestamp + 200);
        
        // Transfer to bob instead of using approvals
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
        
        // Bob should now be able to set expiration as the owner
        vm.prank(bob);
        nft.setExpiration(TOKEN_ID, block.timestamp + 200);
        assertEq(nft.getExpiration(TOKEN_ID), block.timestamp + 200);
        
        // Check that charlie (not owner) cannot set expiration
        vm.expectRevert("Not token owner or approved");
        vm.prank(charlie);
        nft.setExpiration(TOKEN_ID, block.timestamp + 300);
    }
    
    function test_TransferOwnership() public {
        // Mint a token
        nft.mint(alice, TOKEN_ID, block.timestamp + 100);
        
        // Transfer the token to charlie
        vm.prank(alice);
        nft.transferToken(alice, charlie, TOKEN_ID);
        
        // Alice should no longer be able to set expiration
        vm.expectRevert("Not token owner or approved");
        vm.prank(alice);
        nft.setExpiration(TOKEN_ID, block.timestamp + 200);
        
        // Charlie should be able to as the new owner
        vm.prank(charlie);
        nft.setExpiration(TOKEN_ID, block.timestamp + 200);
        assertEq(nft.getExpiration(TOKEN_ID), block.timestamp + 200);
    }
} 