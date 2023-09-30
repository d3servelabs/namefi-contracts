// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./D3BridgeNFT.sol";

/// @custom:security-contact security@d3serve.xyz
contract D3BridgeServiceCredit is 
        Initializable, 
        ERC20Upgradeable, 
        ERC20BurnableUpgradeable, 
        PausableUpgradeable, 
        AccessControlUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public constant CHARGE = 20 * 10 ** 18; // 20 D3BSC
    
    /// A constant address that is used to identify the D3BridgeNFT contract.
    D3BridgeNFT public d3BridgeNftAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC20_init("D3Bridge Service Credit", "D3BSC");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function minterRoleChargeAndSafeMintByName(
        address mintTo, 
        string memory domainName,
        uint256 expirationTime // unix timestamp
    ) public payable {
        require(balanceOf(mintTo) >= CHARGE, "D3BridgeServiceCredit: insufficient balance");
        _transfer(mintTo, address(this), CHARGE); // TODO(audit): check if this is safe
        d3BridgeNftAddress.safeMintByName(mintTo, domainName, expirationTime);
    }
}