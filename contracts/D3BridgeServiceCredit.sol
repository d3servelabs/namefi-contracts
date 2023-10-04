// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/interfaces/IERC165Upgradeable.sol";
import "./D3BridgeNFT.sol";
import "./IChargeableERC20.sol";

/** @custom:security-contact security@d3serve.xyz
 * @custom:version v0
 * The ABI of this interface in javascript array such as
```
[
    "function mint(address to, uint256 amount) public",
    "function charge(address charger, address chargee, uint256 amount, string memory reason, bytes memory extra) external returns (bytes32)",
    "event Charge(address charger, address chargee, uint256 amount, string reason, bytes extra)"

    // ERC20
    "function name() external view returns (string memory)",
    "function symbol() external view returns (string memory)",
    "function decimals() external view returns (uint8)",
    "function totalSupply() external view returns (uint256)",
    "function balanceOf(address account) external view returns (uint256)",
    "function transfer(address recipient, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)",
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function transferFrom(address sender, address recipient, uint256 amount) external returns (bool)",
    "function increaseAllowance(address spender, uint256 addedValue) external returns (bool)",
    "function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool)",
]
```
*/
contract D3BridgeServiceCredit is 
        Initializable, 
        ERC20Upgradeable, 
        ERC20BurnableUpgradeable, 
        PausableUpgradeable, 
        AccessControlUpgradeable,
        IChargeableERC20 {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER");
    bytes32 public constant CHARGER_ROLE = keccak256("CHARGER");

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

    // TODO: update to more general approach of ERC-1363
    function payAndSafeMintByName(
        D3BridgeNFT d3BridgeNftAddress,
        address mintTo, 
        string memory domainName,
        uint256 expirationTime // unix timestamp
    ) public {
        uint256 CHARGE = 20 * 10 ** 18; // 20 D3BSC // TODO: decide charge amount
        require(balanceOf(_msgSender()) >= CHARGE, "D3BridgeServiceCredit: insufficient balance");
        _burn(_msgSender(), CHARGE); // TODO(audit): check if this is safe
        d3BridgeNftAddress.safeMintByNameNoCharge(mintTo, domainName, expirationTime);
    }

    function charge(
            address charger,
            address chargee, 
            uint256 amount, 
            string memory reason, 
            bytes memory extra) external
        returns (bytes32) {
        // We might upgrade this logic to enable endorsable charges, so charger doesn't have to be the msg.sender
        require(charger == _msgSender(), "D3BridgeServiceCredit: must be called by a charger");

        require(hasRole(CHARGER_ROLE, charger), "D3BridgeServiceCredit: must have charger role");

        // chargee has more balance than the charge amount
        require(balanceOf(chargee) >= amount, "D3BridgeServiceCredit: insufficient balance");

        // require the caller to have the CHARGER_ROLE
        _transfer(chargee, charger, amount); // TODO(audit): check if this is safe against reentry attack
        emit Charge(charger, chargee, amount, reason, extra);
        return keccak256("SUCCESS");
    }
}