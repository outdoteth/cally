// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestBuyOption is Fixture {
    uint256 internal vaultId;
    uint256 internal premium;
    uint256 internal strike;
    Cally.Vault internal vault;

    function setUp() public {
        // create vault for babe
        vm.startPrank(babe);

        bayc.mint(babe, 1);
        bayc.setApprovalForAll(address(c), true);

        uint8 premiumIndex = 1;
        premium = c.premiumOptions(premiumIndex);
        uint8 strikeIndex = 1;
        strike = c.strikeOptions(strikeIndex);

        vaultId = c.createVault(1, address(bayc), premiumIndex, 1, strikeIndex, 0, Cally.TokenType.ERC721);
        vault = c.vaults(vaultId);
        vm.stopPrank();
    }

    function testItIncrementsVaultOwnersUncollectedPremiums() public {
        // arrange
        uint256 expectedChange = premium;
        uint256 uncollectedPremiumsBefore = c.ethBalance(babe);

        // act
        c.buyOption{value: premium}(vaultId);
        uint256 uncollectedPremiumsAfter = c.ethBalance(babe);

        // assert
        uint256 uncollectedPremiumsChange = uncollectedPremiumsAfter - uncollectedPremiumsBefore;
        assertEq(uncollectedPremiumsChange, expectedChange, "Should have incremented uncollected premiums for owner");
    }

    function testItSendsPremiumETHToContract() public {
        // arrange
        uint256 expectedChange = premium;
        uint256 balanceBefore = address(c).balance;

        // act
        c.buyOption{value: premium}(vaultId);
        uint256 balanceAfter = address(c).balance;
        uint256 balanceChange = balanceAfter - balanceBefore;

        // assert
        assertEq(balanceChange, expectedChange, "Should have sent ETH to contract");
    }

    function testItMintsOptionERC721ToBuyer() public {
        // act
        uint256 optionId = c.buyOption{value: premium}(vaultId);

        // assert
        assertEq(c.ownerOf(optionId), address(this), "Should have minted option to buyer");
    }

    function testItSetsStrikeToCurrentDutchAuctionPrice() public {
        // arrange
        uint256 expectedStrike = strike;

        // act
        c.buyOption{value: premium}(vaultId);
        strike = c.vaults(vaultId).currentStrike;

        // assert
        assertEq(strike, expectedStrike, "Incorrect strike");
    }

    function testItSetsStrikeToCurrentDutchAuctionPriceAfterElapsedTime() public {
        // arrange
        skip(0.5 days);
        uint256 expectedStrike = strike / 4; // 0.5^2 * strike == strike / 4

        // act
        c.buyOption{value: premium}(vaultId);
        strike = c.vaults(vaultId).currentStrike;

        // assert
        assertEq(strike, expectedStrike, "Incorrect strike");
    }

    function testItSetsStrikeTo0AfterAuctionEnd() public {
        // arrange
        skip(1.1 days);
        uint256 expectedStrike = 0;

        // act
        c.buyOption{value: premium}(vaultId);
        strike = c.vaults(vaultId).currentStrike;

        // assert
        assertEq(strike, expectedStrike, "Incorrect strike");
    }

    function testItUpdatesExpiration() public {
        // arrange
        uint256 expectedExpiration = block.timestamp + vault.durationDays * 1 days;

        // act
        c.buyOption{value: premium}(vaultId);
        uint256 expiration = c.vaults(vaultId).currentExpiration;

        // assert
        assertEq(expiration, expectedExpiration, "Should have set expiration duration days in the future");
    }

    function testItCannotBuyIfAuctionHasNotStarted() public {
        // arrange
        vm.warp(block.timestamp - 100);

        // assert
        vm.expectRevert("Auction not started");
        c.buyOption{value: premium}(vaultId);
    }

    function testItCannotBuyIfVaultIsWithdrawing() public {
        // arrange
        vm.prank(babe);
        c.initiateWithdraw(vaultId);

        // assert
        vm.expectRevert("Vault is being withdrawn");
        c.buyOption{value: premium}(vaultId);
    }

    function testItCannotBuyIfVaultHasAlreadyBeenExercised() public {
        // arrange
        uint256 optionId = c.buyOption{value: premium}(vaultId);
        c.exercise{value: strike}(optionId);

        // assert
        vm.expectRevert("Vault already exercised");
        c.buyOption{value: premium}(vaultId);
    }

    function testItCannotBuyOptionTwice() public {
        // arrange
        c.buyOption{value: premium}(vaultId);

        // assert
        skip(300);
        vm.expectRevert("Auction not started");
        c.buyOption{value: premium}(vaultId);
    }
}
