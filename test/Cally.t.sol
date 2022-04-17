// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "./mocks/MockWeth.sol";
import "./mocks/MockERC721.sol";

import "src/Cally.sol";

contract TestCally is Test {
    Cally internal c;
    MockWeth internal weth;
    MockERC721 internal bayc;

    function setUp() public {
        weth = new MockWeth();
        c = new Cally(address(weth), "http://test/");

        bayc = new MockERC721("Mock Bored Ape Yacht Club", "MBAYC");
    }

    function testInit() public {
        address callyWethAddress = address(c.weth());
        address expectedWethAddress = address(weth);

        assertEq(callyWethAddress, expectedWethAddress, "Should set weth address");
        assertEq(c.baseURI(), "http://test/", "Should set baseURI");
    }

    // test buyOption

    // can't fill unless current option has expired
    // calculate correct strike based on auction start date
    // transfer weth to vault owner
    // force transfer option to buyer with new strike and expiration
    function testBuyOption() public {
        // arrange
        bayc.mint(address(this), 1);
        bayc.setApprovalForAll(address(c), true);
        uint256 vaultId = c.createVault(1, address(bayc), 1, 1, 0, 0);

        weth.deposit{value: 10 ether}();
        weth.transfer(address(c), 100);
        weth.approve(address(c), type(uint256).max);

        c.buyOption(vaultId);
    }

    // check that sender owns option
    // check option hasn't expired
    // transfer strike from sender to vault owner
    // transfer NFT to sender
    // burn option
    // mark vault as exercised

    function testExercise() public {
        // arrange
        bayc.mint(address(this), 1);
        bayc.setApprovalForAll(address(c), true);
        uint256 vaultId = c.createVault(1, address(bayc), 1, 1, 0, 0);

        weth.deposit{value: 10 ether}();
        weth.transfer(address(c), 100);
        weth.approve(address(c), type(uint256).max);

        uint256 optionId = c.buyOption(vaultId);

        c.exercise(optionId);
    }

    function testInitiateWithdraw() public {
        // arrange
        bayc.mint(address(this), 1);
        bayc.setApprovalForAll(address(c), true);
        uint256 vaultId = c.createVault(1, address(bayc), 1, 1, 0, 0);

        c.initiateWithdraw(vaultId);
    }

    function testWithdraw() public {
        // arrange
        bayc.mint(address(this), 1);
        bayc.setApprovalForAll(address(c), true);
        uint256 vaultId = c.createVault(1, address(bayc), 1, 1, 0, 0);

        skip(1 days);

        c.initiateWithdraw(vaultId);
        c.withdraw(vaultId);
    }
}
