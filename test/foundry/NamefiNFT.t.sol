// SPDX-License-Identifier: Apache-2.0+
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/NamefiNFT.sol";
import "../../contracts/NamefiStruct.sol";
import "../../contracts/ExpirableNFT.sol";
import "../../contracts/LockableNFT.sol";
import "../../contracts/IChargeableERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract NamefiNFTTest is Test {
    NamefiNFT public namefiNFTImplementation;
    NamefiNFT public namefiNFT;
    ProxyAdmin public proxyAdmin;
    address public admin;
    address public minter;
    address public user;

    function setUp() public {
        admin = address(1);
        minter = address(2);
        user = address(3);

        // Deploy contract using admin
        vm.startPrank(admin);
        
        // Deploy the implementation contract
        namefiNFTImplementation = new NamefiNFT();
        
        // Deploy proxy admin
        proxyAdmin = new ProxyAdmin();
        
        // Deploy a proxy pointing to the implementation
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(namefiNFTImplementation),
            address(proxyAdmin),
            abi.encodeWithSelector(namefiNFTImplementation.initialize.selector)
        );
        
        // Get a reference to the proxied NamefiNFT
        namefiNFT = NamefiNFT(address(proxy));
        
        // Grant minter role to minter address
        bytes32 MINTER_ROLE = keccak256("MINTER");
        namefiNFT.grantRole(MINTER_ROLE, minter);
        
        vm.stopPrank();
    }

    function testNormalizedDomainNameCheck() public view {
        // Gas profiling
        uint256 gasStart = gasleft();
        bool result = namefiNFT.isNormalizedName("alice.eth");
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for normalized name check: ", gasUsed);
        assertTrue(result);
        
        gasStart = gasleft();
        result = namefiNFT.isNormalizedName("Alice.ETH");
        gasUsed = gasStart - gasleft();
        
        console.log("Gas used for non-normalized name check: ", gasUsed);
        assertFalse(result);
    }

    function testDomainLabelLengthGas() public view {
        // Test with various label lengths
        string[] memory domains = new string[](5);
        domains[0] = "a.eth"; // 1 char label
        domains[1] = "abcdefghij.eth"; // 10 char label
        domains[2] = "abcdefghijabcdefghijabcdefghij.eth"; // 30 char label
        domains[3] = "abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghi.eth"; // 60 char label (valid)
        domains[4] = "abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghija.eth"; // 61 char label (valid)
        
        for (uint i = 0; i < domains.length; i++) {
            uint256 gasStart = gasleft();
            bool result = namefiNFT.isNormalizedName(domains[i]);
            uint256 gasUsed = gasStart - gasleft();
            
            console.log("Gas used for label length check (", bytes(domains[i]).length, "): ", gasUsed);
            
            if (i < 4) {
                assertTrue(result);
            } else {
                assertTrue(result); // 61 chars is still valid (<=63)
            }
        }
    }

    function testMultipleLabelDomainGas() public view {
        // Test with various multi-label domains
        string[] memory domains = new string[](4);
        domains[0] = "a.b.eth"; // 1 char labels
        domains[1] = "abc.def.ghi.eth"; // 3 char labels
        domains[2] = "a.looooooooooooooooooooooooooooooooooong.eth"; // mixed lengths
        domains[3] = "a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.eth"; // many labels
        
        for (uint i = 0; i < domains.length; i++) {
            uint256 gasStart = gasleft();
            bool result = namefiNFT.isNormalizedName(domains[i]);
            uint256 gasUsed = gasStart - gasleft();
            
            console.log("Gas used for multi-label domain (", bytes(domains[i]).length, " bytes): ", gasUsed);
            assertTrue(result);
        }
        
        // Test with invalid label (empty) in between
        string memory invalidDomain = "good..bad.eth"; // empty label in the middle
        uint256 gasStart = gasleft();
        bool result = namefiNFT.isNormalizedName(invalidDomain);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for invalid multi-label domain (empty label): ", gasUsed);
        assertFalse(result);
    }

    function testMintGas() public {
        vm.startPrank(minter);
        
        uint256 expirationTime = block.timestamp + 365 days;
        string memory domainName = "test.eth";
        
        // Gas profiling for minting
        uint256 gasStart = gasleft();
        namefiNFT.safeMintByNameNoCharge(user, domainName, expirationTime);
        uint256 gasUsed = gasStart - gasleft();
        
        console.log("Gas used for minting: ", gasUsed);
        
        // Verify mint was successful
        assertEq(namefiNFT.ownerOf(uint256(keccak256(abi.encodePacked(domainName)))), user);
        
        vm.stopPrank();
    }
} 