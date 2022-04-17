// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestExercise is Fixture {
    uint256 internal vaultId;
    uint256 internal premium;
    Cally.Vault internal vault;
    uint256 optionId;

    function setUp() public {
        // create vault for babe
        vm.startPrank(babe);

        bayc.mint(babe, 1);
        bayc.setApprovalForAll(address(c), true);

        uint8 premiumIndex = 1;
        premium = c.premiumOptions(premiumIndex);

        vaultId = c.createVault(1, address(bayc), premiumIndex, 1, 1, 0);
        vault = c.vaults(vaultId);
        vm.stopPrank();

        // regular addy here
        weth.deposit{value: 10 ether}();
        weth.approve(address(c), type(uint256).max);

        optionId = c.buyOption(vaultId);
    }
}
