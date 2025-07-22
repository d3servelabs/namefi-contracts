// SPDX-License-Identifier: Apache-2.0+
// Author: Team Namefi by D3ServeLabs
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/NamefiNFT.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract LockableNFT_NamefiNFTTest is Test {
    NamefiNFT public nft;
    
    address public deployer;
    address public admin;
    address public minter;
    address public alice;
    address public bob;
    
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    
    string public normalizedDomainName = "token.test.eth";
    uint256 public tokenId; // Will be calculated in setUp
    
    // Events from LockableNFT
    event Lock(uint256 indexed tokenId, bytes extra);
    event Unlock(uint256 indexed tokenId, bytes extra);
    
    function setUp() public {
        deployer = address(this);
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        
        // Set up NamefiNFT with proxy
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        NamefiNFT nftLogic = new NamefiNFT();
        
        TransparentUpgradeableProxy nftProxy = new TransparentUpgradeableProxy(
            address(nftLogic),
            address(proxyAdmin),
            ""
        );
        
        nft = NamefiNFT(address(nftProxy));
        nft.initialize();
        
        // Setup roles
        nft.grantRole(DEFAULT_ADMIN_ROLE, admin);
        nft.grantRole(MINTER_ROLE, minter);
        
        // Renounce deployer roles to clean up
        nft.renounceRole(DEFAULT_ADMIN_ROLE, deployer);
        nft.renounceRole(MINTER_ROLE, deployer);
        
        // Calculate tokenId the same way NamefiNFT does
        tokenId = uint256(keccak256(abi.encodePacked(normalizedDomainName)));
        
        // Mint a test token to alice
        uint256 expirationTime = block.timestamp + 365 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
    }
    
    function test_InitialLockState() public {
        // Verify the token is initially unlocked
        assertEq(nft.ownerOf(tokenId), alice);
        assertFalse(nft.isLocked(tokenId));
    }
    
    function test_MinterCanLock() public {
        // Minter should be able to lock the token
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        
        // Verify lock status
        assertTrue(nft.isLocked(tokenId));
    }
    
    function test_MinterCanUnlock() public {
        // First lock the token
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        assertTrue(nft.isLocked(tokenId));
        
        // Now unlock it
        vm.prank(minter);
        nft.unlockByName(normalizedDomainName);
        
        // Verify unlock status
        assertFalse(nft.isLocked(tokenId));
    }
    
    function test_OwnerCannotLock() public {
        // Owner alice should not be able to lock the token (only minter can)
        vm.expectRevert();
        vm.prank(alice);
        nft.lockByName(normalizedDomainName);
        
        // Token should still be unlocked
        assertFalse(nft.isLocked(tokenId));
    }
    
    function test_TransferRestriction() public {
        // First lock the token
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        
        // Attempt to transfer should fail when locked
        vm.expectRevert(abi.encodeWithSelector(LockableNFT_Locked.selector, tokenId));
        vm.prank(alice);
        nft.safeTransferFromByName(alice, bob, normalizedDomainName);
        
        // Unlock and try again
        vm.prank(minter);
        nft.unlockByName(normalizedDomainName);
        
        // Now transfer should succeed
        vm.prank(alice);
        nft.safeTransferFromByName(alice, bob, normalizedDomainName);
        assertEq(nft.ownerOf(tokenId), bob);
    }
    
    function test_BurnRequiresLock() public {
        // Attempt to burn should fail when not locked
        vm.expectRevert(abi.encodeWithSelector(LockableNFT_NotLocked.selector, tokenId));
        vm.prank(minter);
        nft.burnByName(normalizedDomainName);
        
        // Lock the token
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        
        // Now burn should succeed
        vm.prank(minter);
        nft.burnByName(normalizedDomainName);
        
        // Verify burn
        vm.expectRevert("ERC721: invalid token ID");
        nft.ownerOf(tokenId);
    }
    
    function test_NonMinterCannotUnlock() public {
        // First lock the token
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        
        // Bob should not be able to unlock the token
        vm.expectRevert();
        vm.prank(bob);
        nft.unlockByName(normalizedDomainName);
        
        // Even alice (the owner) cannot unlock
        vm.expectRevert();
        vm.prank(alice);
        nft.unlockByName(normalizedDomainName);
        
        // Token should still be locked
        assertTrue(nft.isLocked(tokenId));
    }
    
    function test_MultipleLockStates() public {
        // Mint more tokens
        string memory domainName2 = "token2.test.eth";
        string memory domainName3 = "token3.test.eth";
        uint256 expirationTime = block.timestamp + 365 days;
        
        vm.startPrank(minter);
        nft.safeMintByNameNoCharge(alice, domainName2, expirationTime);
        nft.safeMintByNameNoCharge(bob, domainName3, expirationTime);
        vm.stopPrank();
        
        uint256 token2 = uint256(keccak256(abi.encodePacked(domainName2)));
        uint256 token3 = uint256(keccak256(abi.encodePacked(domainName3)));
        
        // Lock only token2
        vm.prank(minter);
        nft.lockByName(domainName2);
        
        // Check states
        assertFalse(nft.isLocked(tokenId));
        assertTrue(nft.isLocked(token2));
        assertFalse(nft.isLocked(token3));
        
        // Lock token3
        vm.prank(minter);
        nft.lockByName(domainName3);
        
        // Check all states
        assertFalse(nft.isLocked(tokenId));
        assertTrue(nft.isLocked(token2));
        assertTrue(nft.isLocked(token3));
        
        // Unlock token2
        vm.prank(minter);
        nft.unlockByName(domainName2);
        
        // Final states
        assertFalse(nft.isLocked(tokenId));
        assertFalse(nft.isLocked(token2));
        assertTrue(nft.isLocked(token3));
    }
    
    function test_RedundantLockOperations() public {
        // First lock the token
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        assertTrue(nft.isLocked(tokenId));
        
        // Locking an already locked token should work (no state change)
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        assertTrue(nft.isLocked(tokenId));
        
        // Unlock the token
        vm.prank(minter);
        nft.unlockByName(normalizedDomainName);
        assertFalse(nft.isLocked(tokenId));
        
        // Unlocking an already unlocked token should work (no state change)
        vm.prank(minter);
        nft.unlockByName(normalizedDomainName);
        assertFalse(nft.isLocked(tokenId));
    }
    
    function test_ApprovalDoesNotAllowUnlock() public {
        // Lock the token
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        
        // Alice approves bob to manage the token
        vm.prank(alice);
        nft.approve(bob, tokenId);
        
        // Bob should not be able to unlock the token even with approval
        vm.expectRevert();
        vm.prank(bob);
        nft.unlockByName(normalizedDomainName);
        
        // Token should still be locked
        assertTrue(nft.isLocked(tokenId));
    }
    
    function test_AdminCanGrantUnlockPermission() public {
        // Lock the token
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        
        // Admin grants MINTER role to bob
        vm.prank(admin);
        nft.grantRole(MINTER_ROLE, bob);
        
        // Now bob should be able to unlock the token
        vm.prank(bob);
        nft.unlockByName(normalizedDomainName);
        
        // Token should be unlocked
        assertFalse(nft.isLocked(tokenId));
    }
} 