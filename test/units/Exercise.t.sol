// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestExercise is Fixture {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    uint256 internal vaultId;
    uint256 internal strike;
    Cally.Vault internal vault;
    uint256 internal optionId;
    uint256 internal tokenId;

    function setUp() public {
        // create vault for babe
        vm.startPrank(babe);

        bayc.mint(babe, 1);
        bayc.setApprovalForAll(address(c), true);

        uint8 strikeIndex = 1;
        strike = c.strikeOptions(strikeIndex);
        tokenId = 1;

        vaultId = c.createVault(tokenId, address(bayc), 1, strikeIndex, 1, 0);
        vault = c.vaults(vaultId);
        vm.stopPrank();

        // regular addy here
        weth.deposit{value: 10 ether}();
        weth.approve(address(c), type(uint256).max);

        optionId = c.buyOption(vaultId);
    }

    function testItShouldTransferERC721ToOptionOwner() public {
        // arrange
        uint256 balanceBefore = bayc.balanceOf(address(this));

        // act
        c.exercise(optionId);

        // assert
        assertEq(bayc.ownerOf(tokenId), address(this), "Should have transferred NFT to exerciser");
        assertEq(bayc.balanceOf(address(this)), balanceBefore + 1, "Should have transferred NFT to exerciser");
    }

    function testItTransfersStrikeWethToVaultOwner() public {
        // arrange
        uint256 expectedWethBalanceChange = strike;
        uint256 wethBalanceBefore = weth.balanceOf(babe);

        // act
        c.exercise(optionId);
        uint256 wethBalanceChange = weth.balanceOf(babe) - wethBalanceBefore;

        // assert
        assertEq(wethBalanceChange, expectedWethBalanceChange, "Should have transferred strike to vault owner");
    }

    function testItShouldMarkVaultAsExercised() public {
        // act
        c.exercise(optionId);

        // assert
        bool isExercised = c.vaults(vaultId).isExercised;
        assertTrue(isExercised, "Should have marked vault as exercised");
    }

    function testItShouldBurnOptionERC721() public {
        // act
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(this), address(0), optionId);
        c.exercise(optionId);

        // assert
        vm.expectRevert("NOT_MINTED");
        c.ownerOf(optionId);
    }

    function testCannotExerciseExpiredOption() public {
        // arrange
        skip(vault.durationDays * 1 days);

        // act
        vm.expectRevert("Option has expired");
        c.exercise(optionId);
    }

    function testCannotExerciseOptionYouDontOwn() public {
        // arrange
        vm.prank(babe);

        // act
        vm.expectRevert("You are not the owner");
        c.exercise(optionId);
    }

    function testCannotExerciseOptionTwice() public {
        // arrange
        c.exercise(optionId);

        // act
        vm.expectRevert("NOT_MINTED");
        c.exercise(optionId);
    }
}
