// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestExercise is Fixture {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    uint256 internal vaultId;
    uint256 internal strike;
    uint256 internal optionId;
    uint256 internal tokenId;
    Cally.Vault internal vault;

    function setUp() public {
        // create vault for babe
        vm.startPrank(babe);

        bayc.mint(babe, 1);
        bayc.setApprovalForAll(address(c), true);

        uint8 strikeIndex = 1;
        strike = c.strikeOptions(strikeIndex);
        tokenId = 1;
        uint8 premiumIndex = 1;
        uint256 premium = c.premiumOptions(premiumIndex);

        vaultId = c.createVault(tokenId, address(bayc), premiumIndex, strikeIndex, 1, 0);
        vault = c.vaults(vaultId);
        vm.stopPrank();

        optionId = c.buyOption{value: premium}(vaultId);
    }

    function testItShouldTransferERC721ToOptionOwner() public {
        // arrange
        uint256 balanceBefore = bayc.balanceOf(address(this));

        // act
        c.exercise{value: strike}(optionId);

        // assert
        assertEq(bayc.ownerOf(tokenId), address(this), "Should have transferred NFT to exerciser");
        assertEq(bayc.balanceOf(address(this)), balanceBefore + 1, "Should have transferred NFT to exerciser");
    }

    function testItIncrementsEthBalanceOfVaultOwner() public {
        // arrange
        uint256 expectedChange = strike;
        uint256 balanceBefore = c.ethBalance(babe);

        // act
        c.exercise{value: strike}(optionId);
        uint256 balanceChange = c.ethBalance(babe) - balanceBefore;

        // assert
        assertEq(balanceChange, expectedChange, "Should have incremented vault owner's eth balance");
    }

    function testItShouldMarkVaultAsExercised() public {
        // act
        c.exercise{value: strike}(optionId);

        // assert
        bool isExercised = c.vaults(vaultId).isExercised;
        assertTrue(isExercised, "Should have marked vault as exercised");
    }

    function testItShouldBurnOptionERC721() public {
        // act
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(this), address(0), optionId);
        c.exercise{value: strike}(optionId);

        // assert
        vm.expectRevert("NOT_MINTED");
        c.ownerOf(optionId);
    }

    function testCannotExerciseExpiredOption() public {
        // arrange
        skip(vault.durationDays * 1 days);

        // act
        vm.expectRevert("Option has expired");
        c.exercise{value: strike}(optionId);
    }

    function testCannotExerciseOptionYouDontOwn() public {
        // arrange
        vm.deal(babe, strike);
        vm.prank(babe);

        // act
        vm.expectRevert("You are not the owner");
        c.exercise{value: strike}(optionId);
    }

    function testCannotExerciseOptionTwice() public {
        // arrange
        c.exercise{value: strike}(optionId);

        // act
        vm.expectRevert("NOT_MINTED");
        c.exercise{value: strike}(optionId);
    }
}
