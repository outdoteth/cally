// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ICally.sol";

// create Vault

contract Cally is ICally {
    constructor() {}

    function createVault(
        uint256 tokenId,
        address token,
        uint256 premium,
        uint256 duration,
        uint256 dutchAuctionStartingStrike,
        uint256 dutchAuctionEndingStrike
    ) external {}

    function buyOption(uint256 vaultId) external {}

    function exercise(uint256 vaultId) external {}

    function initiateWithdraw(uint256 vaultId) external {}

    function withdraw(uint256 vaultId) external {}

    function harvest(uint256 vaultId) external {}
}
