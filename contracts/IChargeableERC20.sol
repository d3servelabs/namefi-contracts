// SPDX-License-Identifier: Proprietary
pragma solidity 0.8.19;

interface IChargeableERC20 {
    event Charge(address charger, address chargee, uint256 amount, string reason, bytes extra);
    function charge(
            address charger,
            address chargee, 
            uint256 amount, 
            string memory reason, 
            bytes memory extra) external
        returns (bytes32);
}
