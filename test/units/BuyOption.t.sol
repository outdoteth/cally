// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../mocks/MockWeth.sol";
import "../mocks/MockERC721.sol";

import "../shared/Fixture.t.sol";

import "src/Cally.sol";

contract TestBuyOption is Fixture {
    uint256 internal vaultId;
    uint256 internal premium;
    Cally.Vault internal vault;

    function setUp() public {
        // create vault for babe
        vm.startPrank(babe);

        bayc.mint(babe, 1);
        bayc.setApprovalForAll(address(c), true);

        uint8 premiumIndex = 1;
        premium = c.premiumOptions(premiumIndex);

        vaultId = c.createVault(1, address(bayc), premiumIndex, 1, 1, 0);
        vault = c.vaults(vaultId);
        vm.stopPrank();

        // regular addy here
        weth.deposit{value: 10 ether}();
        weth.approve(address(c), type(uint256).max);
    }

    function testItTransfersPremiumToVaultOwner() public {
        // arrange
        uint256 expectedWethBalanceChange = premium;
        uint256 wethBalanceBefore = weth.balanceOf(babe);

        // act
        c.buyOption(vaultId);
        uint256 wethBalanceChange = weth.balanceOf(babe) - wethBalanceBefore;

        // assert
        assertEq(wethBalanceChange, expectedWethBalanceChange, "Should have sent premium weth to owner");
    }

    function testItMintsOptionERC721ToBuyer() public {
        // act
        uint256 optionId = c.buyOption(vaultId);

        // assert
        assertEq(c.ownerOf(optionId), address(this), "Should have minted option to buyer");
    }

    function testItSetsStrikeToCurrentDutchAuctionPrice() public {
        // TODO: test this after changing to curve
    }

    function testItUpdatesExpiration() public {
        // arrange
        uint256 expectedExpiration = block.timestamp + vault.durationDays * 1 days;

        // act
        c.buyOption(vaultId);
        uint256 expiration = c.vaults(vaultId).currentExpiration;

        // assert
        assertEq(expiration, expectedExpiration, "Should have set expiration duration days in the future");
    }

    function testItCannotBuyIfAuctionHasNotStarted() public {
        // arrange
        vm.warp(block.timestamp - 100);

        // assert
        vm.expectRevert("Auction not started");
        c.buyOption(vaultId);
    }

    function testItCannotBuyIfVaultIsWithdrawing() public {
        // arrange
        vm.prank(babe);
        c.initiateWithdraw(vaultId);

        // assert
        vm.expectRevert("Vault is being withdrawn");
        c.buyOption(vaultId);
    }

    function testItCannotBuyIfVaultHasAlreadyBeenExercised() public {
        // arrange
        uint256 optionId = c.buyOption(vaultId);
        c.exercise(optionId);

        // assert
        vm.expectRevert("Vault already exercised");
        c.buyOption(vaultId);
    }

    function testItCannotBuyOptionTwice() public {
        // arrange
        c.buyOption(vaultId);

        // assert
        skip(300);
        vm.expectRevert("Auction not started");
        c.buyOption(vaultId);
    }
}
