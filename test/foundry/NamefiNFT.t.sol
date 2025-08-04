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

// Helper contract to expose internal functions for testing
contract NamefiNFTExposed is NamefiNFT {
    function exposedEnsureValidFirstChar(string memory domainName) public pure returns (bool) {
        return _ensureValidFirstChar(domainName);
    }

    function exposedEnsureValidLastChar(string memory domainName) public pure returns (bool) {
        return _ensureValidLastChar(domainName);
    }

    function exposedEnsureLdh(string memory domainName) public pure returns (bool) {
        return _ensureLdh(domainName);
    }

    function exposedEnsureLabelLength(string memory domainName) public pure returns (bool) {
        return _ensureLabelLength(domainName);
    }
    
    // Explicitly expose isNormalizedName to measure its gas in the exposed contract
    function exposedIsNormalizedName(string memory domainName) public pure returns (bool) {
        return isNormalizedName(domainName);
    }
}

contract NamefiNFTTest is Test {
    NamefiNFT public namefiNFTImplementation;
    NamefiNFT public namefiNFT;
    NamefiNFTExposed public exposed;
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
        
        // Deploy exposed version for internal function testing
        exposed = new NamefiNFTExposed();
        
        vm.stopPrank();
    }

    function testNormalizedDomainNameCheck() public {
        // First test - correctly measure gas usage
        vm.resumeGasMetering();
        bool result = namefiNFT.isNormalizedName("alice.eth");
        vm.pauseGasMetering();
        assertTrue(result);
        
        // Second test - correctly measure gas usage
        vm.resumeGasMetering();
        result = namefiNFT.isNormalizedName("Alice.ETH");
        vm.pauseGasMetering();
        assertFalse(result);
    }
    
    // Test the exposed isNormalizedName function
    function testExposedIsNormalizedName() public {
        string[] memory domains = new string[](4);
        domains[0] = "a.eth"; // Simple domain
        domains[1] = "abcdefghij.eth"; // Longer domain
        domains[2] = "a-b-c.eth"; // With dashes
        domains[3] = "a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.eth"; // Many labels
        
        for (uint i = 0; i < domains.length; i++) {
            vm.resumeGasMetering();
            bool result = exposed.exposedIsNormalizedName(domains[i]);
            vm.pauseGasMetering();
            assertTrue(result);
        }
        
        // Test invalid inputs
        string[] memory invalidDomains = new string[](3);
        invalidDomains[0] = "UPPERCASE.eth"; // Invalid characters
        invalidDomains[1] = "a..eth"; // Empty label
        invalidDomains[2] = "too-long."; // Ends with dot
        
        for (uint i = 0; i < invalidDomains.length; i++) {
            vm.resumeGasMetering();
            bool result = exposed.exposedIsNormalizedName(invalidDomains[i]);
            vm.pauseGasMetering();
            assertFalse(result);
        }
    }

    // Test gas usage of _ensureLdh
    function testEnsureLdhGas() public {
        string[] memory domains = new string[](4);
        domains[0] = "a.eth"; // Simple domain
        domains[1] = "abcdefghij.eth"; // Longer domain
        domains[2] = "a-b-c.eth"; // With dashes
        domains[3] = "a123.eth"; // With numbers
        
        for (uint i = 0; i < domains.length; i++) {
            vm.resumeGasMetering();
            bool validLdh = exposed.exposedEnsureLdh(domains[i]);
            vm.pauseGasMetering();
            assertTrue(validLdh);
        }
        
        // Test invalid characters
        vm.resumeGasMetering();
        bool invalidLdh = exposed.exposedEnsureLdh("CAPITAL.eth");
        vm.pauseGasMetering();
        assertFalse(invalidLdh);
    }
    
    // Test gas usage of _ensureLabelLength
    function testEnsureLabelLengthGas() public {
        string[] memory domains = new string[](4);
        domains[0] = "a.eth"; // 1 char label
        domains[1] = "abcdefghij.eth"; // 10 char label
        domains[2] = "a.b.c.eth"; // Multiple short labels
        domains[3] = string(abi.encodePacked(
            "abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghi",
            ".eth")); // 60 char label (valid)
        
        for (uint i = 0; i < domains.length; i++) {
            vm.resumeGasMetering();
            bool validLabel = exposed.exposedEnsureLabelLength(domains[i]);
            vm.pauseGasMetering();
            assertTrue(validLabel);
        }
        
        // Test invalid label length (empty label)
        vm.resumeGasMetering();
        bool invalidLabel = exposed.exposedEnsureLabelLength("a..eth");
        vm.pauseGasMetering();
        assertFalse(invalidLabel);
    }

    function testDomainLabelLengthGas() public {
        // Test with various label lengths
        string[] memory domains = new string[](5);
        domains[0] = "a.eth"; // 1 char label
        domains[1] = "abcdefghij.eth"; // 10 char label
        domains[2] = "abcdefghijabcdefghijabcdefghij.eth"; // 30 char label
        domains[3] = "abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghi.eth"; // 60 char label (valid)
        domains[4] = "abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghija.eth"; // 61 char label (valid)
        
        for (uint i = 0; i < domains.length; i++) {
            vm.resumeGasMetering();
            bool result = namefiNFT.isNormalizedName(domains[i]);
            vm.pauseGasMetering();
            
            if (i < 4) {
                assertTrue(result);
            } else {
                assertTrue(result); // 61 chars is still valid (<=63)
            }
        }
    }

    function testMultipleLabelDomainGas() public {
        // Test with various multi-label domains
        string[] memory domains = new string[](4);
        domains[0] = "a.b.eth"; // 1 char labels
        domains[1] = "abc.def.ghi.eth"; // 3 char labels
        domains[2] = "a.looooooooooooooooooooooooooooooooooong.eth"; // mixed lengths
        domains[3] = "a.b.c.d.e.f.g.h.i.j.k.l.m.n.o.p.q.r.s.t.u.v.w.x.y.z.eth"; // many labels
        
        for (uint i = 0; i < domains.length; i++) {
            vm.resumeGasMetering();
            bool validMultiLabel = namefiNFT.isNormalizedName(domains[i]);
            vm.pauseGasMetering();
            assertTrue(validMultiLabel);
        }
        
        // Test with invalid label (empty) in between
        string memory invalidDomain = "good..bad.eth"; // empty label in the middle
        vm.resumeGasMetering();
        bool invalidMultiLabel = namefiNFT.isNormalizedName(invalidDomain);
        vm.pauseGasMetering();
        assertFalse(invalidMultiLabel);
    }

    function testMintGas() public {
        vm.startPrank(minter);
        uint256 expirationTime = block.timestamp + 365 days;
        string memory domainName = "test.eth";
        
        vm.resumeGasMetering();
        namefiNFT.safeMintByNameNoCharge(user, domainName, expirationTime);
        vm.pauseGasMetering();
        
        assertEq(namefiNFT.ownerOf(uint256(keccak256(abi.encodePacked(domainName)))), user);
        vm.stopPrank();
    }

    function testRealWorldDomains() public {
        // 110 typical internet domains to test
        string[] memory domains = new string[](110);
        
        // Original 10 domains
        domains[0] = "google.com";
        domains[1] = "amazon.com";
        domains[2] = "microsoft.com";
        domains[3] = "wikipedia.org";
        domains[4] = "github.com";
        domains[5] = "twitter.com";
        domains[6] = "harvard.edu";
        domains[7] = "bbc.co.uk";
        domains[8] = "wordpress.org";
        domains[9] = "cloudflare.net";
        
        // Additional 100 domains
        domains[10] = "youtube.com";
        domains[11] = "facebook.com";
        domains[12] = "netflix.com";
        domains[13] = "apple.com";
        domains[14] = "instagram.com";
        domains[15] = "linkedin.com";
        domains[16] = "reddit.com";
        domains[17] = "nytimes.com";
        domains[18] = "cnn.com";
        domains[19] = "espn.com";
        domains[20] = "spotify.com";
        domains[21] = "paypal.com";
        domains[22] = "adobe.com";
        domains[23] = "salesforce.com";
        domains[24] = "airbnb.com";
        domains[25] = "uber.com";
        domains[26] = "tesla.com";
        domains[27] = "dropbox.com";
        domains[28] = "slack.com";
        domains[29] = "zoom.us";
        domains[30] = "twitch.tv";
        domains[31] = "ebay.com";
        domains[32] = "walmart.com";
        domains[33] = "target.com";
        domains[34] = "nih.gov";
        domains[35] = "cdc.gov";
        domains[36] = "nasa.gov";
        domains[37] = "stanford.edu";
        domains[38] = "mit.edu";
        domains[39] = "berkeley.edu";
        domains[40] = "oxford.ac.uk";
        domains[41] = "cambridge.org";
        domains[42] = "who.int";
        domains[43] = "un.org";
        domains[44] = "imdb.com";
        domains[45] = "yelp.com";
        domains[46] = "tripadvisor.com";
        domains[47] = "weather.com";
        domains[48] = "etsy.com";
        domains[49] = "pinterest.com";
        domains[50] = "quora.com";
        domains[51] = "medium.com";
        domains[52] = "npr.org";
        domains[53] = "bbc.com";
        domains[54] = "guardian.co.uk";
        domains[55] = "wsj.com";
        domains[56] = "economist.com";
        domains[57] = "telegraph.co.uk";
        domains[58] = "booking.com";
        domains[59] = "expedia.com";
        domains[60] = "ibm.com";
        domains[61] = "oracle.com";
        domains[62] = "intel.com";
        domains[63] = "cisco.com";
        domains[64] = "nvidia.com";
        domains[65] = "amd.com";
        domains[66] = "dell.com";
        domains[67] = "hp.com";
        domains[68] = "lenovo.com";
        domains[69] = "samsung.com";
        domains[70] = "tiktok.com";
        domains[71] = "snapchat.com";
        domains[72] = "whatsapp.com";
        domains[73] = "telegram.org";
        domains[74] = "signal.org";
        domains[75] = "wechat.com";
        domains[76] = "baidu.com";
        domains[77] = "alibaba.com";
        domains[78] = "tencent.com";
        domains[79] = "rakuten.co.jp";
        domains[80] = "yahoo.co.jp";
        domains[81] = "naver.com";
        domains[82] = "yandex.ru";
        domains[83] = "mail.ru";
        domains[84] = "vk.com";
        domains[85] = "weibo.com";
        domains[86] = "shopify.com";
        domains[87] = "squarespace.com";
        domains[88] = "wix.com";
        domains[89] = "godaddy.com";
        domains[90] = "namecheap.com";
        domains[91] = "cloudflare.com";
        domains[92] = "aws.amazon.com";
        domains[93] = "azure.microsoft.com";
        domains[94] = "cloud.google.com";
        domains[95] = "digitalocean.com";
        domains[96] = "heroku.com";
        domains[97] = "gitlab.com";
        domains[98] = "bitbucket.org";
        domains[99] = "stackoverflow.com";
        domains[100] = "w3schools.com";
        domains[101] = "kaggle.com";
        domains[102] = "arxiv.org";
        domains[103] = "researchgate.net";
        domains[104] = "academia.edu";
        domains[105] = "jstor.org";
        domains[106] = "ieee.org";
        domains[107] = "nature.com";
        domains[108] = "science.org";
        domains[109] = "ietf.org";
        
        // To avoid excessive console output, only log stats for first 10
        for (uint i = 0; i < domains.length; i++) {
            vm.resumeGasMetering();
            bool normalResult = namefiNFT.isNormalizedName(domains[i]);
            vm.pauseGasMetering();
            assertTrue(normalResult);
            
            // Also test with the exposed function
            vm.resumeGasMetering();
            bool exposedResult = exposed.exposedIsNormalizedName(domains[i]);
            vm.pauseGasMetering();
            assertTrue(exposedResult);
            
            // Measure individual component costs
            vm.resumeGasMetering();
            bool ldhResult = exposed.exposedEnsureLdh(domains[i]);
            vm.pauseGasMetering();
            assertTrue(ldhResult);
            
            vm.resumeGasMetering();
            bool labelResult = exposed.exposedEnsureLabelLength(domains[i]);
            vm.pauseGasMetering();
            assertTrue(labelResult);
            
            // Only log stats for the first 10 domains to keep output manageable
            if (i < 10) {
                // Use individual console.log calls instead of trying to format everything together
                console.log("Domain:", domains[i]);
                console.log("Length:", bytes(domains[i]).length);
                console.log("Labels:", countLabels(domains[i]));
                console.log("---");
            }
        }
        
        console.log("Successfully tested all 110 real-world domains");
    }

    // Helper function to count the number of labels in a domain
    function countLabels(string memory domain) internal pure returns (uint) {
        uint labels = 1; // Start with 1 for the last label
        for (uint i = 0; i < bytes(domain).length; i++) {
            if (bytes(domain)[i] == 0x2e) { // "."
                labels++;
            }
        }
        return labels;
    }

    // Test the new _ensureValidLastChar function specifically
    function testEnsureValidLastChar() public {
        // Test valid last characters
        string[] memory validLast = new string[](4);
        validLast[0] = "alice.eth";     // ends with lowercase letter
        validLast[1] = "alice.et9";     // ends with number 9
        validLast[2] = "alice.et0";     // ends with number 0
        validLast[3] = "alice.etz";     // ends with letter z
        
        for (uint i = 0; i < validLast.length; i++) {
            vm.resumeGasMetering();
            bool result = exposed.exposedEnsureValidLastChar(validLast[i]);
            vm.pauseGasMetering();
            assertTrue(result, string(abi.encodePacked("_ensureValidLastChar should accept: ", validLast[i])));
        }
        
        // Test invalid last characters (ICANN non-compliant)
        string[] memory invalidLast = new string[](6);
        invalidLast[0] = "alice.eth-";   // ends with dash
        invalidLast[1] = "alice.eth.";   // ends with dot
        invalidLast[2] = "alice.eth_";   // ends with underscore
        invalidLast[3] = "alice.ethA";   // ends with uppercase letter
        invalidLast[4] = "alice.eth@";   // ends with special character
        invalidLast[5] = "alice.eth ";   // ends with space
        
        for (uint i = 0; i < invalidLast.length; i++) {
            vm.resumeGasMetering();
            bool result = exposed.exposedEnsureValidLastChar(invalidLast[i]);
            vm.pauseGasMetering();
            assertFalse(result, string(abi.encodePacked("_ensureValidLastChar should reject: ", invalidLast[i])));
        }
        
        // Test edge case: empty string
        vm.resumeGasMetering();
        bool emptyResult = exposed.exposedEnsureValidLastChar("");
        vm.pauseGasMetering();
        assertFalse(emptyResult, "_ensureValidLastChar should reject empty string");
    }

    // Test the new _ensureValidFirstChar function specifically
    function testEnsureValidFirstChar() public {
        // Test valid first characters
        string[] memory validFirst = new string[](4);
        validFirst[0] = "alice.eth";    // starts with lowercase letter
        validFirst[1] = "9alice.eth";   // starts with number 9
        validFirst[2] = "0alice.eth";   // starts with number 0
        validFirst[3] = "ztest.eth";    // starts with letter z
        
        for (uint i = 0; i < validFirst.length; i++) {
            vm.resumeGasMetering();
            bool result = exposed.exposedEnsureValidFirstChar(validFirst[i]);
            vm.pauseGasMetering();
            assertTrue(result, string(abi.encodePacked("_ensureValidFirstChar should accept: ", validFirst[i])));
        }
        
        // Test invalid first characters
        string[] memory invalidFirst = new string[](5);
        invalidFirst[0] = "-alice.eth";  // starts with dash
        invalidFirst[1] = ".alice.eth";  // starts with dot
        invalidFirst[2] = "_alice.eth";  // starts with underscore
        invalidFirst[3] = "Alice.eth";   // starts with uppercase letter
        invalidFirst[4] = "@alice.eth";  // starts with special character
        
        for (uint i = 0; i < invalidFirst.length; i++) {
            vm.resumeGasMetering();
            bool result = exposed.exposedEnsureValidFirstChar(invalidFirst[i]);
            vm.pauseGasMetering();
            assertFalse(result, string(abi.encodePacked("_ensureValidFirstChar should reject: ", invalidFirst[i])));
        }
        
        // Test edge case: empty string
        vm.resumeGasMetering();
        bool emptyResult = exposed.exposedEnsureValidFirstChar("");
        vm.pauseGasMetering();
        assertFalse(emptyResult, "_ensureValidFirstChar should reject empty string");
    }

    // Test boundary conditions for domain length and character positioning
    function testBoundaryConditions() public {
        // Test minimum length requirements
        string[] memory tooShort = new string[](2);
        tooShort[0] = "ab";             // 2 characters (below minimum of 3)
        tooShort[1] = "a";              // 1 character
        
        for (uint i = 0; i < tooShort.length; i++) {
            vm.resumeGasMetering();
            bool result = namefiNFT.isNormalizedName(tooShort[i]);
            vm.pauseGasMetering();
            assertFalse(result, string(abi.encodePacked("Should reject too short domain: ", tooShort[i])));
        }
        
        // Test minimum valid length
        vm.resumeGasMetering();
        bool minValidResult = namefiNFT.isNormalizedName("a.b");  // 3 characters, minimum valid
        vm.pauseGasMetering();
        assertTrue(minValidResult, "Should accept minimum valid length domain: a.b");
        
        // Test domains with only two characters that don't have dots
        string[] memory noDots = new string[](3);
        noDots[0] = "aa";               // 2 chars, no dots
        noDots[1] = "99";               // 2 numbers, no dots  
        noDots[2] = "a9";               // mixed, no dots
        
        for (uint i = 0; i < noDots.length; i++) {
            vm.resumeGasMetering();
            bool result = namefiNFT.isNormalizedName(noDots[i]);
            vm.pauseGasMetering();
            assertFalse(result, string(abi.encodePacked("Should reject short domain without dots: ", noDots[i])));
        }
        
        // Test edge case: exactly 3 characters with various patterns
        string[] memory threeChars = new string[](4);
        threeChars[0] = "a.b";          // valid: letter.letter
        threeChars[1] = "9.a";          // valid: number.letter
        threeChars[2] = "a.9";          // valid: letter.number
        threeChars[3] = "9.9";          // valid: number.number
        
        for (uint i = 0; i < threeChars.length; i++) {
            vm.resumeGasMetering();
            bool result = namefiNFT.isNormalizedName(threeChars[i]);
            vm.pauseGasMetering();
            assertTrue(result, string(abi.encodePacked("Should accept valid 3-char domain: ", threeChars[i])));
        }
    }

    // Test that ICANN compliance for last character is enforced
    function testStrictLastCharCompliance() public {
        // These domains are rejected by isNormalizedName due to ICANN compliance (last char validation enabled)
        string[] memory nonCompliantDomains = new string[](3);
        nonCompliantDomains[0] = "alice.eth-";    // ends with dash
        nonCompliantDomains[1] = "alice.ethA";    // ends with uppercase
        nonCompliantDomains[2] = "bob.org_";      // ends with underscore
        
        for (uint i = 0; i < nonCompliantDomains.length; i++) {
            string memory domain = nonCompliantDomains[i];
            
            // Current behavior: these fail overall validation due to ICANN compliance
            vm.resumeGasMetering();
            bool currentlyValid = namefiNFT.isNormalizedName(domain);
            vm.pauseGasMetering();
            assertFalse(currentlyValid, string(abi.encodePacked("ICANN compliance rejects: ", domain)));
            
            // They also fail strict last char validation
            vm.resumeGasMetering();
            bool strictLastChar = exposed.exposedEnsureValidLastChar(domain);
            vm.pauseGasMetering();
            assertFalse(strictLastChar, string(abi.encodePacked("Strict last char rejects: ", domain)));
        }
        
        // These domains would still be valid with strict compliance
        string[] memory compliantDomains = new string[](3);
        compliantDomains[0] = "alice.eth";     // ends with letter
        compliantDomains[1] = "bob.org9";      // ends with number
        compliantDomains[2] = "test.comz";     // ends with letter z
        
        for (uint i = 0; i < compliantDomains.length; i++) {
            string memory domain = compliantDomains[i];
            
            vm.resumeGasMetering();
            bool currentlyValid = namefiNFT.isNormalizedName(domain);
            vm.pauseGasMetering();
            assertTrue(currentlyValid, string(abi.encodePacked("Currently accepts: ", domain)));
            
            vm.resumeGasMetering();
            bool strictLastChar = exposed.exposedEnsureValidLastChar(domain);
            vm.pauseGasMetering();
            assertTrue(strictLastChar, string(abi.encodePacked("Strict last char also accepts: ", domain)));
        }
    }

    // Test that _ensureLdh doesn't check the last 2 characters (important boundary behavior)
    function testEnsureLdhLastTwoCharsNotChecked() public {
        // _ensureLdh loop: for (uint i = 1; i < bytes(domainName).length - 2; i++)
        // This means for "alice.ethAB" (length 10), it only checks indices 1-7
        // Indices 8-9 (last 2 chars 'A' and 'B') are NOT checked by _ensureLdh
        
        string[] memory lastTwoInvalid = new string[](4);
        lastTwoInvalid[0] = "alice.ethAB";    // last 2 chars are uppercase
        lastTwoInvalid[1] = "alice.eth@#";    // last 2 chars are special chars
        lastTwoInvalid[2] = "alice.ethA9";    // second-to-last is uppercase
        lastTwoInvalid[3] = "alice.eth9A";    // last is uppercase
        
        for (uint i = 0; i < lastTwoInvalid.length; i++) {
            vm.resumeGasMetering();
            bool ldhResult = exposed.exposedEnsureLdh(lastTwoInvalid[i]);
            vm.pauseGasMetering();
            assertTrue(ldhResult, string(abi.encodePacked("_ensureLdh should pass (doesn't check last 2 chars): ", lastTwoInvalid[i])));
            
            // But if we put invalid chars in positions that ARE checked, it should fail
            string memory middleInvalid = "alice.Aeth";  // uppercase 'A' in middle (index 6, which IS checked)
            vm.resumeGasMetering();
            bool middleLdhResult = exposed.exposedEnsureLdh(middleInvalid);
            vm.pauseGasMetering();
            assertFalse(middleLdhResult, "_ensureLdh should reject invalid chars in checked positions");
        }
    }

    // Test specific edge cases for the _ensureLdh function boundaries
    function testEnsureLdhBoundaries() public {
        // Test that _ensureLdh correctly validates middle characters while 
        // first and last chars are handled separately
        
        // These should pass _ensureLdh even though they might fail overall validation
        // because _ensureLdh only checks indices 1 to length-2
        string[] memory middleValidDomains = new string[](4);
        middleValidDomains[0] = "a-b.eth";      // dash in middle (valid)
        middleValidDomains[1] = "a.b-c.eth";    // dash in middle label (valid)
        middleValidDomains[2] = "a123b.eth";    // numbers in middle (valid)
        middleValidDomains[3] = "a.b.c.eth";    // dots separating labels (valid)
        
        for (uint i = 0; i < middleValidDomains.length; i++) {
            vm.resumeGasMetering();
            bool ldhResult = exposed.exposedEnsureLdh(middleValidDomains[i]);
            vm.pauseGasMetering();
            assertTrue(ldhResult, string(abi.encodePacked("_ensureLdh should accept valid middle chars: ", middleValidDomains[i])));
        }
        
        // Test that _ensureLdh correctly rejects invalid middle characters
        string[] memory middleInvalidDomains = new string[](3);
        middleInvalidDomains[0] = "aXb.eth";        // uppercase in middle (invalid)
        middleInvalidDomains[1] = "a@b.eth";        // special char in middle (invalid)
        middleInvalidDomains[2] = "a b.eth";        // space in middle (invalid)
        
        for (uint i = 0; i < middleInvalidDomains.length; i++) {
            vm.resumeGasMetering();
            bool ldhResult = exposed.exposedEnsureLdh(middleInvalidDomains[i]);
            vm.pauseGasMetering();
            assertFalse(ldhResult, string(abi.encodePacked("_ensureLdh should reject invalid middle chars: ", middleInvalidDomains[i])));
        }
        
        // Verify that domains starting/ending with edge chars still pass _ensureLdh
        // because _ensureLdh doesn't check first/last positions
        string[] memory edgeValidForLdh = new string[](2);
        edgeValidForLdh[0] = "-alice.eth";      // starts with dash (invalid overall, but _ensureLdh should pass)
        edgeValidForLdh[1] = "alice.eth-";      // ends with dash (_ensureLdh should pass, but overall validation fails due to ICANN compliance)
        
        for (uint i = 0; i < edgeValidForLdh.length; i++) {
            vm.resumeGasMetering();
            bool ldhResult = exposed.exposedEnsureLdh(edgeValidForLdh[i]);
            vm.pauseGasMetering();
            assertTrue(ldhResult, string(abi.encodePacked("_ensureLdh should pass for edge cases (it doesn't check first/last): ", edgeValidForLdh[i])));
            
            // Check overall validation behavior
            vm.resumeGasMetering();
            bool overallResult = namefiNFT.isNormalizedName(edgeValidForLdh[i]);
            vm.pauseGasMetering();
            
            // Both cases should fail overall validation now that ICANN compliance is enforced
            assertFalse(overallResult, string(abi.encodePacked("Overall validation fails due to ICANN compliance: ", edgeValidForLdh[i])));
        }
    }
} 