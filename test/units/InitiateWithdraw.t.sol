// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestInitiateWithdraw is Fixture {
    uint256 vaultId;
    Cally.Vault internal vault;

    function setUp() public {
        bayc.mint(address(this), 1);
        bayc.setApprovalForAll(address(c), true);

        vaultId = c.createVault(1, address(bayc), 1, 1, 1, 0);
    }

    function testItMarksVaultAsWithdrawing() public {
        // act
        c.initiateWithdraw(vaultId);

        // assert
        bool isWithdrawing = c.vaults(vaultId).isWithdrawing;
        assertTrue(isWithdrawing, "Should have marked vault as withdrawing");
    }

    function testItCannotWithdrawVaultYouDontOwn() public {
        // arrange
        vm.prank(babe);

        // act
        vm.expectRevert("You are not the owner");
        c.initiateWithdraw(vaultId);
    }
}
