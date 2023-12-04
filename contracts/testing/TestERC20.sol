// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// AccessControl
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TestERC20 is ERC20, AccessControl {

    constructor () ERC20(
        "TestERC20",
        "TEST"
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address account, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(account, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        // only token holder or approved spender can transfer
        require(sender == msg.sender || allowance(sender, msg.sender) >= amount, "ERC20: transfer amount exceeds allowance");
        _transfer(sender, recipient, amount);
        return true;
    }
}