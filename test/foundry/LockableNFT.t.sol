// SPDX-License-Identifier: Apache-2.0+
// Author: Team Namefi by D3ServeLabs
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/LockableNFT.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Concrete implementation of LockableNFT for testing
contract TestLockableNFT is ERC721, LockableNFT {
    address public minter;
    
    constructor() ERC721("TestLockable", "TLOCK") {
        minter = msg.sender;
    }
    
    function mint(address to, uint256 tokenId) external {
        require(msg.sender == minter, "Not authorized to mint");
        _mint(to, tokenId);
    }
    
    function lock(uint256 tokenId, bytes memory extra) external payable override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not token owner or approved");
        _lock(tokenId, extra);
    }
    
    function unlock(uint256 tokenId, bytes memory extra) external payable override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not token owner or approved");
        _unlock(tokenId, extra);
    }
    
    function transferToken(address from, address to, uint256 tokenId) external whenNotLocked(tokenId, "") {
        _transfer(from, to, tokenId);
    }
    
    function burnToken(uint256 tokenId) external whenLocked(tokenId, "") {
        _burn(tokenId);
    }
}

contract LockableNFTTest is Test {
    TestLockableNFT public nft;
    
    address public deployer;
    address public alice;
    address public bob;
    
    uint256 public constant TOKEN_ID = 1;
    
    // Events imported from LockableNFT
    event Lock(uint256 indexed tokenId, bytes extra);
    event Unlock(uint256 indexed tokenId, bytes extra);
    
    function setUp() public {
        deployer = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        
        nft = new TestLockableNFT();
        nft.mint(alice, TOKEN_ID);
    }
    
    function test_InitialState() public {
        assertEq(nft.ownerOf(TOKEN_ID), alice);
        assertEq(nft.isLocked(TOKEN_ID), false);
    }
    
    function test_Lock() public {
        vm.startPrank(alice);
        
        // Check that we can lock a token
        bytes memory lockData = abi.encode("Lock reason");
        vm.expectEmit(true, false, false, true);
        emit Lock(TOKEN_ID, lockData);
        nft.lock(TOKEN_ID, lockData);
        
        // Verify lock status
        assertTrue(nft.isLocked(TOKEN_ID));
        assertTrue(nft.isLocked(TOKEN_ID, ""));
        
        vm.stopPrank();
    }
    
    function test_Unlock() public {
        // First lock the token
        vm.prank(alice);
        nft.lock(TOKEN_ID, "");
        assertTrue(nft.isLocked(TOKEN_ID));
        
        // Now unlock it
        vm.startPrank(alice);
        bytes memory unlockData = abi.encode("Unlock reason");
        vm.expectEmit(true, false, false, true);
        emit Unlock(TOKEN_ID, unlockData);
        nft.unlock(TOKEN_ID, unlockData);
        
        // Verify unlock status
        assertFalse(nft.isLocked(TOKEN_ID));
        
        vm.stopPrank();
    }
    
    function test_TransferRestriction() public {
        // First lock the token
        vm.prank(alice);
        nft.lock(TOKEN_ID, "");
        
        // Attempt to transfer should fail when locked
        vm.expectRevert(abi.encodeWithSelector(LockableNFT_Locked.selector, TOKEN_ID));
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
        
        // Unlock and try again
        vm.prank(alice);
        nft.unlock(TOKEN_ID, "");
        
        // Now transfer should succeed
        vm.prank(alice);
        nft.transferToken(alice, bob, TOKEN_ID);
        assertEq(nft.ownerOf(TOKEN_ID), bob);
    }
    
    function test_BurnRequiresLock() public {
        // Attempt to burn should fail when not locked
        vm.expectRevert(abi.encodeWithSelector(LockableNFT_NotLocked.selector, TOKEN_ID));
        vm.prank(alice);
        nft.burnToken(TOKEN_ID);
        
        // Lock the token
        vm.prank(alice);
        nft.lock(TOKEN_ID, "");
        
        // Now burn should succeed
        vm.prank(alice);
        nft.burnToken(TOKEN_ID);
        
        // Verify burn
        vm.expectRevert("ERC721: invalid token ID");
        nft.ownerOf(TOKEN_ID);
    }
    
    function test_OnlyOwnerCanLock() public {
        // Bob is not the owner and should not be able to lock
        vm.expectRevert("Not token owner or approved");
        vm.prank(bob);
        nft.lock(TOKEN_ID, "");
        
        // Approve bob to manage the token
        vm.prank(alice);
        nft.approve(bob, TOKEN_ID);
        
        // Now bob should be able to lock
        vm.prank(bob);
        nft.lock(TOKEN_ID, "");
        assertTrue(nft.isLocked(TOKEN_ID));
    }
    
    function test_OnlyOwnerCanUnlock() public {
        // First lock the token
        vm.prank(alice);
        nft.lock(TOKEN_ID, "");
        
        // Bob is not the owner and should not be able to unlock
        vm.expectRevert("Not token owner or approved");
        vm.prank(bob);
        nft.unlock(TOKEN_ID, "");
        
        // Approve bob to manage the token
        vm.prank(alice);
        nft.approve(bob, TOKEN_ID);
        
        // Now bob should be able to unlock
        vm.prank(bob);
        nft.unlock(TOKEN_ID, "");
        assertFalse(nft.isLocked(TOKEN_ID));
    }
    
    function test_MultipleLockStates() public {
        // Test with multiple tokens
        uint256 token2 = 2;
        uint256 token3 = 3;
        
        nft.mint(alice, token2);
        nft.mint(bob, token3);
        
        // Lock only token2
        vm.prank(alice);
        nft.lock(token2, "");
        
        // Check states
        assertFalse(nft.isLocked(TOKEN_ID));
        assertTrue(nft.isLocked(token2));
        assertFalse(nft.isLocked(token3));
        
        // Lock token3
        vm.prank(bob);
        nft.lock(token3, "");
        
        // Check all states
        assertFalse(nft.isLocked(TOKEN_ID));
        assertTrue(nft.isLocked(token2));
        assertTrue(nft.isLocked(token3));
        
        // Unlock token2
        vm.prank(alice);
        nft.unlock(token2, "");
        
        // Final states
        assertFalse(nft.isLocked(TOKEN_ID));
        assertFalse(nft.isLocked(token2));
        assertTrue(nft.isLocked(token3));
    }
    
    function test_LockNonExistentToken() public {
        uint256 nonExistentToken = 999;
        
        // Attempting to lock a non-existent token should revert
        vm.expectRevert("ERC721: invalid token ID");
        vm.prank(alice);
        nft.lock(nonExistentToken, "");
    }
    
    function test_UnlockNonExistentToken() public {
        uint256 nonExistentToken = 999;
        
        // Attempting to unlock a non-existent token should revert
        vm.expectRevert("ERC721: invalid token ID");
        vm.prank(alice);
        nft.unlock(nonExistentToken, "");
    }
    
    function test_RedundantLockOperations() public {
        // First lock the token
        vm.prank(alice);
        nft.lock(TOKEN_ID, "");
        assertTrue(nft.isLocked(TOKEN_ID));
        
        // Locking an already locked token should work (no state change)
        vm.prank(alice);
        nft.lock(TOKEN_ID, "");
        assertTrue(nft.isLocked(TOKEN_ID));
        
        // Unlock the token
        vm.prank(alice);
        nft.unlock(TOKEN_ID, "");
        assertFalse(nft.isLocked(TOKEN_ID));
        
        // Unlocking an already unlocked token should work (no state change)
        vm.prank(alice);
        nft.unlock(TOKEN_ID, "");
        assertFalse(nft.isLocked(TOKEN_ID));
    }
    
    function test_ApprovalBehaviorWithLocking() public {
        // Approve bob to manage the token
        vm.prank(alice);
        nft.approve(bob, TOKEN_ID);
        assertEq(nft.getApproved(TOKEN_ID), bob);
        
        // Lock the token
        vm.prank(alice);
        nft.lock(TOKEN_ID, "");
        
        // Check that approval is still active
        assertEq(nft.getApproved(TOKEN_ID), bob);
        
        // Bob should be able to unlock the token using his approval
        vm.prank(bob);
        nft.unlock(TOKEN_ID, "");
        assertFalse(nft.isLocked(TOKEN_ID));
        
        // Check that approval is still active after unlocking
        assertEq(nft.getApproved(TOKEN_ID), bob);
    }
    
    function test_LockWithEthValue() public {
        // Test sending ETH when locking
        uint256 ethAmount = 0.1 ether;
        vm.deal(alice, ethAmount);
        
        // Send ETH during lock (current implementation ignores the ETH, but test verifies it doesn't revert)
        vm.prank(alice);
        nft.lock{value: ethAmount}(TOKEN_ID, "");
        assertTrue(nft.isLocked(TOKEN_ID));
        
        // Ensure the ETH was transferred from alice
        assertEq(alice.balance, 0);
    }
    
    function test_UnlockWithEthValue() public {
        // First lock the token
        vm.prank(alice);
        nft.lock(TOKEN_ID, "");
        
        // Test sending ETH when unlocking
        uint256 ethAmount = 0.1 ether;
        vm.deal(alice, ethAmount);
        
        // Send ETH during unlock (current implementation ignores the ETH, but test verifies it doesn't revert)
        vm.prank(alice);
        nft.unlock{value: ethAmount}(TOKEN_ID, "");
        assertFalse(nft.isLocked(TOKEN_ID));
        
        // Ensure the ETH was transferred from alice
        assertEq(alice.balance, 0);
    }
} 