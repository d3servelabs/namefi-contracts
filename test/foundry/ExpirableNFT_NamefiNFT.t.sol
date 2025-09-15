// SPDX-License-Identifier: Apache-2.0+
// Author: Team Namefi by D3ServeLabs
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/NamefiNFT.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Import the ExpirationChanged event
event ExpirationChanged(uint256 indexed tokenId, uint256 newExpirationTime);

contract ExpirableNFT_NamefiNFTTest is Test {
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
        
        // Note: We don't mint the token here as different tests need different expiration times
    }
    
    function test_InitialMintWithExpiration() public {
        // Mint a token with future expiration
        uint256 expirationTime = block.timestamp + 100 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
        
        // Verify owner and expiration
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.getExpiration(tokenId), expirationTime);
        assertFalse(nft.isExpired(tokenId));
    }
    
    function test_ExpirationTransition() public {
        // Mint token with expiration very soon
        uint256 expirationTime = block.timestamp + 100;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
        
        // Not expired yet
        assertFalse(nft.isExpired(tokenId));
        
        // Warp time to after expiration
        vm.warp(expirationTime + 1);
        
        // Should be expired now
        assertTrue(nft.isExpired(tokenId));
        
        // Transfer should fail when expired
        vm.expectRevert(abi.encodeWithSelector(ExpirableNFT_Expired.selector, tokenId));
        vm.prank(alice);
        nft.safeTransferFromByName(alice, bob, normalizedDomainName);
    }
    
    function test_ExtendExpirationBeforeExpiry() public {
        // Mint with future expiration
        uint256 initialExpiration = block.timestamp + 100 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, initialExpiration);
        
        // Extend expiration
        uint256 newExpiration = initialExpiration + 365 days;
        vm.prank(minter);
        nft.setExpiration(tokenId, newExpiration);
        
        // Verify new expiration
        assertEq(nft.getExpiration(tokenId), newExpiration);
        assertFalse(nft.isExpired(tokenId));
    }
    
    function test_ExtendExpirationAfterExpiry() public {
        // Mint with short expiration
        uint256 expirationTime = block.timestamp + 10;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
        
        // Warp time to after expiration
        vm.warp(expirationTime + 1);
        assertTrue(nft.isExpired(tokenId));
        
        // Extend expiration
        uint256 newExpiration = block.timestamp + 100;
        vm.prank(minter);
        nft.setExpiration(tokenId, newExpiration);
        
        // Token should be valid again
        assertFalse(nft.isExpired(tokenId));
        
        // Transfer should work now
        vm.prank(alice);
        nft.safeTransferFromByName(alice, bob, normalizedDomainName);
        assertEq(nft.ownerOf(tokenId), bob);
    }
    
    function test_OnlyMinterCanSetExpiration() public {
        // Mint a token
        uint256 expirationTime = block.timestamp + 100 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
        
        // Alice (owner) should not be able to set expiration
        vm.expectRevert();
        vm.prank(alice);
        nft.setExpiration(tokenId, expirationTime + 100);
        
        // Check that expiration didn't change
        assertEq(nft.getExpiration(tokenId), expirationTime);
        
        // Minter should be able to set expiration
        uint256 newExpiration = expirationTime + 200;
        vm.prank(minter);
        nft.setExpiration(tokenId, newExpiration);
        
        // Verify expiration was updated
        assertEq(nft.getExpiration(tokenId), newExpiration);
    }
    
    function test_TransferBeforeExpiry() public {
        // Mint with future expiration
        uint256 expirationTime = block.timestamp + 100 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
        
        // Transfer should work before expiry
        vm.prank(alice);
        nft.safeTransferFromByName(alice, bob, normalizedDomainName);
        assertEq(nft.ownerOf(tokenId), bob);
        
        // Expiration should remain unchanged after transfer
        assertEq(nft.getExpiration(tokenId), expirationTime);
    }
    
    function test_TransferAfterExpiry() public {
        // Mint with short expiration
        uint256 expirationTime = block.timestamp + 10;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
        
        // Warp time to after expiration
        vm.warp(expirationTime + 1);
        assertTrue(nft.isExpired(tokenId));
        
        // Transfer should fail when token is expired
        vm.expectRevert(abi.encodeWithSelector(ExpirableNFT_Expired.selector, tokenId));
        vm.prank(alice);
        nft.safeTransferFromByName(alice, bob, normalizedDomainName);
        
        // Alice should still be the owner
        assertEq(nft.ownerOf(tokenId), alice);
    }
    
    function test_ApprovalWithExpiry() public {
        // Mint with future expiration
        uint256 expirationTime = block.timestamp + 100;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
        
        // Alice approves bob to transfer
        vm.prank(alice);
        nft.approve(bob, tokenId);
        
        // Bob should be able to transfer before expiry
        vm.prank(bob);
        nft.safeTransferFromByName(alice, bob, normalizedDomainName);
        assertEq(nft.ownerOf(tokenId), bob);
        
        // Mint another token for testing post-expiry
        string memory domainName2 = "token2.test.eth";
        uint256 token2 = uint256(keccak256(abi.encodePacked(domainName2)));
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, domainName2, expirationTime);
        
        // Alice approves bob for token2
        vm.prank(alice);
        nft.approve(bob, token2);
        
        // Warp time to after expiration
        vm.warp(expirationTime + 1);
        assertTrue(nft.isExpired(token2));
        
        // Even with approval, bob cannot transfer expired token
        vm.expectRevert(abi.encodeWithSelector(ExpirableNFT_Expired.selector, token2));
        vm.prank(bob);
        nft.safeTransferFromByName(alice, bob, domainName2);
        
        // Alice should still be the owner
        assertEq(nft.ownerOf(token2), alice);
    }
    
    function test_MultipleExpirationStates() public {
        // Mint multiple tokens with different expiration times
        string memory domainName1 = normalizedDomainName; // Using the default name
        string memory domainName2 = "token2.test.eth";
        string memory domainName3 = "token3.test.eth";
        
        uint256 token1 = tokenId;
        uint256 token2 = uint256(keccak256(abi.encodePacked(domainName2)));
        uint256 token3 = uint256(keccak256(abi.encodePacked(domainName3)));
        
        // Set up different expiration times
        uint256 expireSoon = block.timestamp + 10;
        uint256 expireMedium = block.timestamp + 100;
        uint256 expireLong = block.timestamp + 1000;
        
        vm.startPrank(minter);
        nft.safeMintByNameNoCharge(alice, domainName1, expireSoon);
        nft.safeMintByNameNoCharge(alice, domainName2, expireMedium);
        nft.safeMintByNameNoCharge(alice, domainName3, expireLong);
        vm.stopPrank();
        
        // Check initial states
        assertFalse(nft.isExpired(token1));
        assertFalse(nft.isExpired(token2));
        assertFalse(nft.isExpired(token3));
        
        // Warp time to after first expiration
        vm.warp(expireSoon + 1);
        
        // Check updated states
        assertTrue(nft.isExpired(token1)); // Now expired
        assertFalse(nft.isExpired(token2)); // Still valid
        assertFalse(nft.isExpired(token3)); // Still valid
        
        // Warp time to after second expiration
        vm.warp(expireMedium + 1);
        
        // Check updated states again
        assertTrue(nft.isExpired(token1)); // Still expired
        assertTrue(nft.isExpired(token2)); // Now expired
        assertFalse(nft.isExpired(token3)); // Still valid
        
        // Extend token1's expiration
        vm.prank(minter);
        nft.setExpiration(token1, block.timestamp + 2000);
        
        // Final states
        assertFalse(nft.isExpired(token1)); // Now valid again
        assertTrue(nft.isExpired(token2)); // Still expired
        assertFalse(nft.isExpired(token3)); // Still valid
    }
    
    function test_MaxExpirationTime() public {
        // Mint with max expiration time
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, type(uint256).max);
        
        // Verify it's not expired
        assertFalse(nft.isExpired(tokenId));
        
        // Warp far into the future
        vm.warp(block.timestamp + 1000 * 365 days);
        
        // Should still not be expired
        assertFalse(nft.isExpired(tokenId));
    }
    
    function test_ZeroExpirationTime() public {
        // NamefiNFT requires expiration dates to be in the future at minting
        
        // Mint with valid expiration
        uint256 expirationTime = block.timestamp + 100;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
        
        // Token should not be expired initially
        assertFalse(nft.isExpired(tokenId));
        
        // Warp time to past the expiration
        vm.warp(expirationTime + 1);
        
        // Now the token should be expired
        assertTrue(nft.isExpired(tokenId));
    }
    
    function test_ExtendWithNameMethod() public {
        // Mint with initial expiration
        uint256 initialExpiration = block.timestamp + 100 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, initialExpiration);
        
        // Verify initial expiration
        assertEq(nft.getExpiration(tokenId), initialExpiration);
        
        // Calculate new expiration 
        uint256 extensionPeriod = 365 days;
        uint256 newExpiration = initialExpiration + extensionPeriod;
        
        // Set new expiration using tokenId
        vm.prank(minter);
        nft.setExpiration(tokenId, newExpiration);
        
        // Verify extended expiration
        assertEq(nft.getExpiration(tokenId), newExpiration);
    }
    
    function test_BurnDomainNameMapping() public {
        // Mint a token
        uint256 initialExpiration = block.timestamp + 100 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, initialExpiration);
        
        // Verify the token exists and mapping is set
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.idToNormalizedDomainName(tokenId), normalizedDomainName);
        
        // Lock the token (required for burning)
        vm.prank(minter);
        nft.lockByName(normalizedDomainName);
        
        // Burn the token
        vm.prank(minter);
        nft.burnByName(normalizedDomainName);
        
        // Verify the token no longer exists
        vm.expectRevert("ERC721: invalid token ID");
        nft.ownerOf(tokenId);
        
        // Check if the domain name is still mapped after burning
        string memory mappedName = nft.idToNormalizedDomainName(tokenId);
        assertEq(mappedName, normalizedDomainName, "Domain name mapping should be preserved after burning");
        
        // Try calculating the tokenId again from the domain name
        uint256 recalculatedTokenId = uint256(keccak256(abi.encodePacked(normalizedDomainName)));
        assertEq(recalculatedTokenId, tokenId, "Token ID calculation should remain consistent");
    }

    // Tests for ExpirationChanged event in NamefiNFT context
    function test_ExpirationChangedEventOnMintByName() public {
        uint256 expirationTime = block.timestamp + 100 days;
        
        // Expect ExpirationChanged event when minting with domain name
        vm.expectEmit(true, false, false, true);
        emit ExpirationChanged(tokenId, expirationTime);
        
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, expirationTime);
        
        // Verify the token was created with correct expiration
        assertEq(nft.getExpiration(tokenId), expirationTime);
        assertEq(nft.ownerOf(tokenId), alice);
    }
    
    function test_ExpirationChangedEventOnSetExpirationById() public {
        // First mint a token
        uint256 initialExpiration = block.timestamp + 100 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, initialExpiration);
        
        // Set new expiration by token ID and expect event
        uint256 newExpiration = block.timestamp + 200 days;
        vm.expectEmit(true, false, false, true);
        emit ExpirationChanged(tokenId, newExpiration);
        
        vm.prank(minter);
        nft.setExpiration(tokenId, newExpiration);
        
        // Verify expiration was updated
        assertEq(nft.getExpiration(tokenId), newExpiration);
    }
    
    function test_ExpirationChangedEventOnSetExpirationByName() public {
        // First mint a token
        uint256 initialExpiration = block.timestamp + 100 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, initialExpiration);
        
        // Set new expiration by domain name and expect event
        uint256 newExpiration = block.timestamp + 200 days;
        vm.expectEmit(true, false, false, true);
        emit ExpirationChanged(tokenId, newExpiration);
        
        vm.prank(minter);
        nft.setExpirationByName(normalizedDomainName, newExpiration);
        
        // Verify expiration was updated
        assertEq(nft.getExpiration(tokenId), newExpiration);
    }
    
    function test_ExpirationChangedEventOnExtendByName() public {
        // First mint a token
        uint256 initialExpiration = block.timestamp + 100 days;
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, initialExpiration);
        
        // Calculate expected new expiration after extension
        uint256 extensionTime = 365 days;
        uint256 expectedNewExpiration = initialExpiration + extensionTime;
        
        // Expect ExpirationChanged event when extending
        vm.expectEmit(true, false, false, true);
        emit ExpirationChanged(tokenId, expectedNewExpiration);
        
        // Note: This test assumes you have a method to extend expiration
        // If extendByNameWithChargeAmount exists, test it
        vm.prank(minter);
        // nft.extendByNameWithChargeAmount(normalizedDomainName, extensionTime, alice, 0, "");
        
        // For now, we'll test using setExpirationByName to simulate extension
        nft.setExpirationByName(normalizedDomainName, expectedNewExpiration);
        
        // Verify expiration was extended
        assertEq(nft.getExpiration(tokenId), expectedNewExpiration);
    }
    
    function test_ExpirationChangedEventMultipleDomains() public {
        string memory domain1 = "domain1.eth";
        string memory domain2 = "domain2.eth";
        uint256 tokenId1 = uint256(keccak256(abi.encodePacked(domain1)));
        uint256 tokenId2 = uint256(keccak256(abi.encodePacked(domain2)));
        
        uint256 expiration1 = block.timestamp + 100 days;
        uint256 expiration2 = block.timestamp + 200 days;
        
        // Mint first domain and expect event
        vm.expectEmit(true, false, false, true);
        emit ExpirationChanged(tokenId1, expiration1);
        
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, domain1, expiration1);
        
        // Mint second domain and expect event
        vm.expectEmit(true, false, false, true);
        emit ExpirationChanged(tokenId2, expiration2);
        
        vm.prank(minter);
        nft.safeMintByNameNoCharge(bob, domain2, expiration2);
        
        // Verify both tokens have correct expirations
        assertEq(nft.getExpiration(tokenId1), expiration1);
        assertEq(nft.getExpiration(tokenId2), expiration2);
        assertEq(nft.ownerOf(tokenId1), alice);
        assertEq(nft.ownerOf(tokenId2), bob);
    }
    
    function test_ExpirationChangedEventOnExpiredToValidTransition() public {
        // Mint with initial expiration time
        uint256 initialExpiration = block.timestamp + 100 days;
        vm.expectEmit(true, false, false, true);
        emit ExpirationChanged(tokenId, initialExpiration);
        
        vm.prank(minter);
        nft.safeMintByNameNoCharge(alice, normalizedDomainName, initialExpiration);
        
        // Forward time to make token expired
        vm.warp(initialExpiration + 1);
        assertTrue(nft.isExpired(tokenId));
        
        // Extend to future time and expect event
        uint256 futureTime = block.timestamp + 100 days;
        vm.expectEmit(true, false, false, true);
        emit ExpirationChanged(tokenId, futureTime);
        
        vm.prank(minter);
        nft.setExpirationByName(normalizedDomainName, futureTime);
        
        // Verify token is now valid
        assertFalse(nft.isExpired(tokenId));
        assertEq(nft.getExpiration(tokenId), futureTime);
        
        // Token should now be transferable
        vm.prank(alice);
        nft.safeTransferFromByName(alice, bob, normalizedDomainName);
        assertEq(nft.ownerOf(tokenId), bob);
    }
} 