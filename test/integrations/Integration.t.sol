// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestIntegration is Fixture {
    receive() external payable {}

    /*
        standard flow:
            createVault
            buyOption
            exercise
            harvest
    */
    function testStandardFlow(
        uint256 tokenIdOrAmount,
        uint8 premiumIndex,
        uint8 durationDays,
        uint8 dutchAuctionStartingStrikeIndex,
        uint256 dutchAuctionReserveStrike,
        uint24 skipTime
    ) public {
        // arrange
        vm.assume(tokenIdOrAmount > 0);
        vm.assume(durationDays > 0);
        vm.assume(premiumIndex < 17);
        vm.assume(dutchAuctionStartingStrikeIndex < 19);
        vm.assume(dutchAuctionReserveStrike < c.strikeOptions(dutchAuctionStartingStrikeIndex));

        link.mint(address(this), tokenIdOrAmount);
        link.approve(address(c), type(uint256).max);

        uint256 premium = c.premiumOptions(premiumIndex);

        uint256 ethBalanceBefore = address(this).balance;
        uint256 babeLinkBalanceBefore = link.balanceOf(babe);

        // act
        // createVault
        skip(skipTime);
        uint256 vaultId = c.createVault(
            tokenIdOrAmount,
            address(link),
            premiumIndex,
            durationDays,
            dutchAuctionStartingStrikeIndex,
            dutchAuctionReserveStrike,
            Cally.TokenType.ERC20
        );

        // buyOption
        skip(skipTime);
        vm.prank(babe);
        vm.deal(babe, premium);
        uint256 optionId = c.buyOption{value: premium}(vaultId);
        uint256 strike = c.vaults(vaultId).currentStrike;
        uint256 expiration = c.vaults(vaultId).currentExpiration;

        // exercise
        skip(skipTime);
        vm.prank(babe);
        vm.deal(babe, strike);
        bool isExercised = false;
        if (block.timestamp < expiration) {
            c.exercise{value: strike}(optionId);
            isExercised = true;
        } else {
            vm.expectRevert("Option has expired");
            c.exercise{value: strike}(optionId);
        }

        // harvest
        c.harvest();

        // assert
        if (isExercised) {
            assertEq(link.balanceOf(babe) - babeLinkBalanceBefore, tokenIdOrAmount, "babe should have been paid link");
        }

        uint256 balanceChange = address(this).balance - ethBalanceBefore;
        isExercised
            ? assertEq(balanceChange, strike + premium, "Should have harvested strike + premium if exercised")
            : assertEq(balanceChange, premium, "Should have harvested premium if not exercised");

        assertEq(c.ethBalance(address(this)), 0, "Should have reset owner's ethBalance");
    }

    /*
        withdrawal flow:
            createVault
            buyOption
            [option expires]
            initiateWithdraw
            withdraw
    */
    function testEarlyWithdrawFlow(
        uint256 tokenIdOrAmount,
        uint8 premiumIndex,
        uint8 durationDays,
        uint8 dutchAuctionStartingStrikeIndex,
        uint256 dutchAuctionReserveStrike,
        uint24 skipTime
    ) public {
        // arrange
        vm.assume(tokenIdOrAmount > 0);
        vm.assume(durationDays > 0);
        vm.assume(premiumIndex < 17);
        vm.assume(dutchAuctionStartingStrikeIndex < 19);
        vm.assume(dutchAuctionReserveStrike < c.strikeOptions(dutchAuctionStartingStrikeIndex));

        link.mint(address(this), tokenIdOrAmount);
        link.approve(address(c), type(uint256).max);

        uint256 premium = c.premiumOptions(premiumIndex);

        // act
        // createVault
        skip(skipTime);
        uint256 vaultId = c.createVault(
            tokenIdOrAmount,
            address(link),
            premiumIndex,
            durationDays,
            dutchAuctionStartingStrikeIndex,
            dutchAuctionReserveStrike,
            Cally.TokenType.ERC20
        );

        // buy option
        skip(skipTime);
        vm.prank(babe);
        vm.deal(babe, premium);
        uint256 optionId = c.buyOption{value: premium}(vaultId);
        uint256 expiration = c.vaults(vaultId).currentExpiration;

        // expire option
        vm.warp(expiration + 1);

        // initiate withdraw
        skip(skipTime);
        c.initiateWithdraw(vaultId);

        // withdraw
        skip(skipTime);
        c.withdraw(vaultId);

        // assert
        assertEq(link.balanceOf(address(this)), tokenIdOrAmount, "Should have returned link tokens");

        vm.expectRevert("NOT_MINTED");
        c.ownerOf(vaultId);

        vm.expectRevert("NOT_MINTED");
        c.ownerOf(optionId);
    }

    /*
        fee claim flow:
            setFee
            createVault
            buyOption
            [option expires]
            buyOption
            exercise
            withdrawProtocolFees
    */
    function testFeeClaimFlow(
        uint256 tokenIdOrAmount,
        uint8 premiumIndex,
        uint8 durationDays,
        uint8 dutchAuctionStartingStrikeIndex,
        uint256 dutchAuctionReserveStrike,
        uint24 skipTime
    ) public {
        // arrange
        vm.assume(tokenIdOrAmount > 0);
        vm.assume(durationDays > 0);
        vm.assume(premiumIndex < 17);
        vm.assume(dutchAuctionStartingStrikeIndex < 19);
        vm.assume(dutchAuctionReserveStrike < c.strikeOptions(dutchAuctionStartingStrikeIndex));

        link.mint(address(this), tokenIdOrAmount);
        link.approve(address(c), type(uint256).max);

        uint256 premium = c.premiumOptions(premiumIndex);
        uint16 feeRate = 30; // 3%
        c.setFee(feeRate);

        uint256 ethBalanceBefore = address(this).balance;

        // act
        // createVault
        skip(skipTime);
        uint256 vaultId = c.createVault(
            tokenIdOrAmount,
            address(link),
            premiumIndex,
            durationDays,
            dutchAuctionStartingStrikeIndex,
            dutchAuctionReserveStrike,
            Cally.TokenType.ERC20
        );

        // buy option
        skip(skipTime);
        vm.prank(babe);
        vm.deal(babe, premium);
        c.buyOption{value: premium}(vaultId);
        uint256 expiration = c.vaults(vaultId).currentExpiration;

        // expire option
        vm.warp(expiration + 1);

        // buy option
        skip(skipTime);
        vm.prank(babe);
        vm.deal(babe, premium);
        uint256 optionId = c.buyOption{value: premium}(vaultId);
        uint256 strike = c.vaults(vaultId).currentStrike;
        expiration = c.vaults(vaultId).currentExpiration;

        // exercise
        vm.prank(babe);
        vm.deal(babe, strike);
        c.exercise{value: strike}(optionId);

        // withdrawProtocolFees
        c.withdrawProtocolFees();

        // assert
        uint256 expectedFee = (strike * feeRate) / 1000;
        assertEq(address(this).balance - ethBalanceBefore, expectedFee, "Should have taken 3% fees");
        assertEq(
            c.ethBalance(address(this)),
            premium + premium + strike - expectedFee,
            "Should have deducted fee from vault owner's ethBalance"
        );
    }
}
