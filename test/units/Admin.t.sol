// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestAdmin is Test, Fixture {
    function testItSetsFee() public {
        // arrange
        uint16 newFeeRate = (29 * 1000) / 100; // 29%

        // act
        c.setFee(newFeeRate);
        uint16 feeRate = c.feeRate();

        // assert
        assertEq(feeRate, newFeeRate, "Should have set fee rate");
    }

    function testItCannotSetFeeHigherThanThreshold() public {
        // arrange
        uint16 newFeeRate = (1000 * 31) / 100; // 31%

        // act
        vm.expectRevert("Fee cannot be larger than 30%");
        c.setFee(newFeeRate);
    }

    function testItCannotLetNonAdminSetFee() public {
        // arrange
        vm.prank(babe);

        // act
        vm.expectRevert("Ownable: caller is not the owner");
        c.setFee(1000);
    }

    function testCannotLetNonAdminWithdrawProtocolFees() public {
        // arrange
        vm.prank(babe);

        // act
        vm.expectRevert("Ownable: caller is not the owner");
        c.withdrawProtocolFees();
    }
}
