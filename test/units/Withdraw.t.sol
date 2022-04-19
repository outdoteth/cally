// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestWithdraw is Fixture {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    uint256 internal tokenId;
    uint256 internal vaultId;
    uint256 internal premium;
    uint256 internal strike;
    Cally.Vault internal vault;

    // solhint-disable-next-line
    receive() external payable {}

    function setUp() public {
        tokenId = 100;
        bayc.mint(address(this), tokenId);
        bayc.setApprovalForAll(address(c), true);

        uint8 premiumIndex = 1;
        premium = c.premiumOptions(premiumIndex);
        uint8 strikeIndex = 1;
        strike = c.strikeOptions(strikeIndex);
        vaultId = c.createVault(tokenId, address(bayc), premiumIndex, strikeIndex, 1, 0);
    }

    function testItTransfersERC721BackToOwner() public {
        // arrange
        c.initiateWithdraw(vaultId);
        skip(1);
        uint256 balanceBefore = bayc.balanceOf(address(this));

        // act
        c.withdraw(vaultId);
        uint256 balanceAfter = bayc.balanceOf(address(this));

        // assert
        assertEq(bayc.ownerOf(tokenId), address(this));
        assertEq(balanceAfter - balanceBefore, 1);
    }

    function testItBurnsVaultERC721() public {
        // arrange
        c.initiateWithdraw(vaultId);
        skip(1);

        // act
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(this), address(0), vaultId);
        c.withdraw(vaultId);

        // assert
        vm.expectRevert("NOT_MINTED");
        c.ownerOf(vaultId);
    }

    function testItBurnsOptionERC721() public {
        // arrange
        uint256 optionId = vaultId + 1;
        c.initiateWithdraw(vaultId);
        skip(1);

        // act
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), address(0), optionId);
        c.withdraw(vaultId);

        // assert
        vm.expectRevert("NOT_MINTED");
        c.ownerOf(optionId);
    }

    function testItCannotWithdrawWhileOptionIsActive() public {
        // arrange
        vm.startPrank(babe);
        vm.deal(babe, 10 ether);
        c.buyOption{value: premium}(vaultId);
        vm.stopPrank();

        skip(100);
        c.initiateWithdraw(vaultId);

        // act
        vm.expectRevert("Option still active");
        c.withdraw(vaultId);
    }

    function testItCannotWithdrawIfVaultIsNotInWithdrawableState() public {
        // act
        vm.expectRevert("Vault not in withdrawable state");
        c.withdraw(vaultId);
    }

    function testItCannotWithdrawIfOptionIsExercised() public {
        // arrange
        vm.startPrank(babe);
        vm.deal(babe, 30 ether);
        uint256 optionId = c.buyOption{value: premium}(vaultId);
        c.exercise{value: strike}(optionId);
        vm.stopPrank();

        // act
        vm.expectRevert("Vault already exercised");
        c.withdraw(vaultId);
    }

    function testItCannotWithdrawVaultYouDontOwn() public {
        // arrange
        vm.prank(babe);

        // act
        vm.expectRevert("You are not the owner");
        c.withdraw(vaultId);
    }

    function testItCannotWithdrawTwice() public {
        // arrange
        c.initiateWithdraw(vaultId);
        skip(1);

        // act
        c.withdraw(vaultId);
        vm.expectRevert("NOT_MINTED");
        c.withdraw(vaultId);
    }
}