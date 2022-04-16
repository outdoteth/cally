// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ICally {
    // events

    // functions

    // creates a perpetual covered call vault
    function createVault(
        uint256 tokenId,
        address token,
        uint256 premium,
        uint256 duration,
        uint256 dutchAuctionStartingStrike,
        uint256 dutchAuctionEndingStrike
    ) external;

    // buys the call at current auction price if auction is live
    function buyOption(uint256 vaultId) external;

    // exercises the call, sends strike, receives NFTs, check that option is live and not expired
    function exercise(uint256 vaultId) external;

    // stops the vault
    function initiateWithdraw(uint256 vaultId) external;

    // sends NFTs back when the vault has stopped
    function withdraw(uint256 vaultId) external;

    // claims all of the premiums
    function harvest(uint256 vaultId) external;
}
