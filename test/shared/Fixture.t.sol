// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../mocks/MockWeth.sol";
import "../mocks/MockERC721.sol";

import "src/Cally.sol";

abstract contract Fixture is Test {
    Cally internal c;
    MockWeth internal weth;
    MockERC721 internal bayc;

    address internal babe;

    constructor() {
        weth = new MockWeth();
        c = new Cally(address(weth), "http://test/");
        bayc = new MockERC721("Mock Bored Ape Yacht Club", "MBAYC");

        babe = address(0xbabe);
        vm.label(babe, "Babe");

        // make sure timestamp is not 0
        vm.warp(0xffff);
    }
}
