// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor () ERC20(
        "TestERC20",
        "TEST"
    ) {}
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        // only token holder or approved spender can transfer
        require(sender == msg.sender || allowance(sender, msg.sender) >= amount, "ERC20: transfer amount exceeds allowance");
        _transfer(sender, recipient, amount);
        return true;
    }
}