// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../mocks/MockWeth.sol";
import "../mocks/MockERC721.sol";

import "../shared/Fixture.t.sol";

import "src/Cally.sol";

contract TestBuyOption is Test, Fixture {
    uint256 vaultId;
    uint256 premium;

    function setUp() public {
        // create vault for babe
        address babe = address(0xbabe);
        vm.label(babe, "Babe");
        vm.startPrank(babe);

        bayc.mint(babe, 1);
        bayc.setApprovalForAll(address(c), true);

        uint8 premiumIndex = 1;
        premium = c.premiumOptions(premiumIndex);

        vaultId = c.createVault(1, address(bayc), premiumIndex, 1, 1, 0);
        vm.stopPrank();

        // regular addy here
        weth.deposit{value: 1 ether}();
        weth.approve(address(c), type(uint256).max);
    }

    function testItTransfersPremiumToVaultOwner() public {
        // arrange


        c.buyOption(vaultId);

        assert
    }
}
