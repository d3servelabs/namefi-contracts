// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";


import "@openzeppelin/contracts-upgradeable/interfaces/IERC165Upgradeable.sol";
import "./D3BridgeNFT.sol";
import "./IChargeableERC20.sol";
import "./IBuyableERC20.sol";

/** @custom:security-contact security@d3serve.xyz
 * @custom:version v0.2
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
        IChargeableERC20,
        IBuyableERC20 {
    uint256 private _buyableSupply; // slot 0
    mapping(IERC20Upgradeable => uint256) private _priceMap;  // slot 1
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

    function buyWithEthers() payable public {
        // TODO buyableSupplyath?
        uint256 buyAmount =
            msg.value * 1e9  // gwei amount
            / _price(address(0)); // token wad

        require(_buyableSupply >= buyAmount, 
            "D3BridgeServiceCredit: insufficient buyable supply");
        _buyableSupply -= buyAmount;
        _mint(_msgSender(), buyAmount);
        emit BuyToken(_msgSender(), buyAmount, address(0), msg.value);
    }

    function buyableSupply() public view returns (uint256) {
        return _buyableSupply;
    }

    // receive and fallback all point to buyWithEthers
    receive() external payable {
        buyWithEthers();
    }

    fallback() external payable {
        buyWithEthers();
    }

    function increaseBuyableSupply(uint256 amount) public override 
        onlyRole(MINTER_ROLE)
        whenNotPaused {
        _buyableSupply = _buyableSupply + amount; // TODO do we need SafeMath?
        emit IncreaseBuyableSupply(amount);
    }

    // Price of GWad of this Token (buyToken) per GWad of payToken
    function _price(address payToken) internal view returns (uint256) {
        uint256 payPrice = _priceMap[IERC20Upgradeable(payToken)];
        if (payPrice > 0) {
            return payPrice;
        }
        revert("D3BridgeServiceCredit: unsupported payToken");
    }
    
    function setPrice(address payToken, uint256 newPrice) external override onlyRole(MINTER_ROLE) {
        _priceMap[IERC20Upgradeable(payToken)] = newPrice;
        emit SetPrice(payToken, newPrice);
    }

    function price(address payToken) external override view returns (uint256) {
        return _price(payToken);
    }
    
    function buy(uint256 buyAmount, address payToken, uint256 payAmount) external payable virtual {
        _buy(buyAmount, payToken, payAmount);
    }

    function _buy(uint256 buyAmount, address payToken, uint256 payAmount) 
        internal virtual whenNotPaused {
        require(_buyableSupply >= buyAmount, "D3BridgeServiceCredit: insufficient buyable supply");
        
        uint256 totalPrice = _price(payToken) * (buyAmount / 1e9);
        require(payAmount >= totalPrice, "D3BridgeServiceCredit: payAmount insufficient.");
        
        if (payToken == address(0)) {
            require(msg.value >= totalPrice, "D3BridgeServiceCredit: insufficient ethers");
            // the ethers is received by the contract in the amount of msg.value
        } else {
            // According to ERC20 It is not reliable to rely on the return value of
            // transferFrom or exception as the indicator of success.
            // For example, USDC and DAI has a return boolean, but USDT doesn't.
            // USDC(proxy): https://etherscan.io/token/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48#code
            // DAI: https://etherscan.io/token/0x6b175474e89094c44da98b954eedeac495271d0f#code
            // USDT: https://etherscan.io/address/0xdac17f958d2ee523a2206206994597c13d831ec7#code

            uint256 beforeBalance = IERC20Upgradeable(payToken).balanceOf(address(this));
            // TODO consideration: transfer fee
            // the following pattern will never work if the IERC20Upgradeable(payToken) charges a transfer fee,
            // and it will need to be handled by a new standard or at least a new interface.
            IERC20Upgradeable(payToken).transferFrom(_msgSender(), address(this), totalPrice);
            uint256 afterBalance = IERC20Upgradeable(payToken).balanceOf(address(this));
            require(afterBalance - beforeBalance >= totalPrice, "D3BridgeServiceCredit: incorrect payAmount");
        }
        _mint(_msgSender(), buyAmount);
        if (payToken == address(0)) {
            payable(_msgSender()).transfer(msg.value - totalPrice);
        } // We've only charged the IERC20Upgradeable(payToken) for the totalPrice and nothing else.
        emit BuyToken(_msgSender(), buyAmount, payToken, totalPrice);
    }
}
