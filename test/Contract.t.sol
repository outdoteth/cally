// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/Cally.sol";

contract TestContract is Test {
    Cally c;

    function setUp() public {
        c = new Cally();
    }

    function testBar() public {
        assertEq(uint256(1), 1, "ok");
    }

    function testFoo(uint256 x) public {
        vm.assume(x < type(uint128).max);
        assertEq(x + x, x * 2);
    }
}
