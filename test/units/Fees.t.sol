// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestFees is Test, Fixture {
    event Harvested(address indexed from, uint256 amount);

    uint256 internal vaultId;
    uint256 internal strike;
    uint256 internal optionId;
    uint256 internal tokenId;
    uint256 internal tokenAmount;
    uint256 internal premium;
    uint8 internal strikeIndex;
    uint8 internal premiumIndex;
    Cally.Vault internal vault;

    function setUp() public {
        // create vault for babe
        vm.startPrank(babe);

        tokenId = 1;
        bayc.mint(babe, tokenId);
        bayc.setApprovalForAll(address(c), true);

        tokenAmount = 1337;
        link.mint(babe, tokenAmount);
        link.approve(address(c), type(uint256).max);

        strikeIndex = 1;
        strike = c.strikeOptions(strikeIndex);
        premiumIndex = 1;
        premium = c.premiumOptions(premiumIndex);
        vaultId = c.createVault(tokenId, address(bayc), premiumIndex, strikeIndex, 1, 0, Cally.TokenType.ERC721);
        vault = c.vaults(vaultId);
        vm.stopPrank();

        vm.prank(bob);
        vm.deal(bob, 100 ether);
        optionId = c.buyOption{value: premium}(vaultId);
    }

    receive() external payable {}

    function testItIncrementsProtocolUnclaimedFees() public {
        // arrange
        uint16 feeRate = (3 * 1000) / 100; // 3%
        c.setFee(feeRate);
        uint256 expectedUnclaimedFees = (30 * strike) / 1000;

        vm.startPrank(babe);
        tokenId = 2;
        bayc.mint(babe, tokenId);
        vaultId = c.createVault(tokenId, address(bayc), premiumIndex, strikeIndex, 1, 0, Cally.TokenType.ERC721);
        vault = c.vaults(vaultId);
        vm.stopPrank();

        vm.prank(bob);
        vm.deal(bob, 100 ether);
        optionId = c.buyOption{value: premium}(vaultId);

        // act
        vm.prank(bob);
        c.exercise{value: strike}(optionId);
        uint256 unclaimedFees = c.protocolUnclaimedFees();

        // assert
        assertEq(unclaimedFees, expectedUnclaimedFees, "Fee should have been 3% of strike");
    }

    function testItDoesNotIncrementUnclaimedFeesIfFeeRateIs0() public {
        // act
        vm.prank(bob);
        c.exercise{value: strike}(optionId);
        uint256 unclaimedFees = c.protocolUnclaimedFees();

        // assert
        assertEq(unclaimedFees, 0, "Fee should have been 0% of strike");
    }

    function testItWithdrawsProtocolFees() public {
        // arrange
        uint16 feeRate = (3 * 1000) / 100; // 3%
        c.setFee(feeRate);
        vm.prank(bob);
        c.exercise{value: strike}(optionId);
        uint256 unclaimedFees = c.protocolUnclaimedFees();
        uint256 balanceBefore = address(this).balance;

        // act
        c.withdrawProtocolFees();
        uint256 change = address(this).balance - balanceBefore;

        // arrange
        assertEq(change, unclaimedFees, "Should have sent ETH to owner");
    }

    function testItEmitsEventWhenWithdrawingFees() public {
        // arrange
        uint256 unclaimedFees = c.protocolUnclaimedFees();

        // act
        vm.expectEmit(true, true, false, false);
        emit Harvested(address(this), unclaimedFees);
        c.withdrawProtocolFees();
    }
}
