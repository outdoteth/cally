// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestCreateVault is Test, Fixture {
    function setUp() public {
        bayc.mint(address(this), 1);
        bayc.mint(address(this), 2);
        bayc.mint(address(this), 100);
        bayc.setApprovalForAll(address(c), true);
    }

    function testItSendsERC721ForCollateral() public {
        // act
        c.createVault(1, address(bayc), 2, 1, 0, 0, Cally.TokenType.ERC721);

        // assert
        assertEq(bayc.balanceOf(address(c)), 1, "Should have sent BAYC to Cally");
        assertEq(bayc.ownerOf(1), address(c), "Should have sent BAYC to Cally");
    }

    function testItMintsVaultERC721ToCreator() public {
        // act
        uint256 vaultId = c.createVault(1, address(bayc), 2, 1, 0, 0, Cally.TokenType.ERC721);

        // assert
        assertEq(c.ownerOf(vaultId), address(this), "Should have minted vault token");
    }

    function testItCreatesVaultDetails() public {
        // arrange
        uint256 tokenId = 1;
        address token = address(bayc);
        uint8 premium = 2;
        uint8 durationDays = 3;
        uint8 dutchAuctionStartingStrike = 3;
        uint8 dutchAuctionEndingStrike = 3;
        Cally.TokenType tokenType = Cally.TokenType.ERC721;

        // act
        uint256 vaultId = c.createVault(
            tokenId,
            token,
            premium,
            durationDays,
            dutchAuctionStartingStrike,
            dutchAuctionEndingStrike,
            tokenType
        );

        // assert
        Cally.Vault memory vault = c.vaults(vaultId);
        assertEq(vault.tokenId, tokenId, "Should have set tokenId");
        assertEq(vault.token, token, "Should have set token");
        assertEq(vault.premium, premium, "Should have set premium");
        assertEq(vault.durationDays, durationDays, "Should have set durationDays");
        assertEq(vault.dutchAuctionStartingStrike, dutchAuctionStartingStrike, "Should have set starting strike");
        assertEq(vault.dutchAuctionEndingStrike, dutchAuctionEndingStrike, "Should have set ending strike");
        assertEq(uint8(vault.tokenType), uint8(tokenType), "Should have set tokenType");
    }

    function testItIncrementsVaultId() public {
        // act
        uint256 vaultId = c.createVault(1, address(bayc), 2, 1, 0, 0, Cally.TokenType.ERC721);

        // assert
        uint256 vaultIndex = c.vaultIndex();
        assertEq(vaultIndex, 3, "Should have incremented vaultIndex by 2");
        assertEq(vaultId, 3, "Should have returned vaultId");
    }

    function testItIncrementsVaultIdMultipleTimes() public {
        // act
        uint256 vaultId1 = c.createVault(1, address(bayc), 2, 1, 0, 0, Cally.TokenType.ERC721);
        uint256 vaultId2 = c.createVault(2, address(bayc), 2, 1, 0, 0, Cally.TokenType.ERC721);
        uint256 vaultId3 = c.createVault(100, address(bayc), 2, 1, 0, 0, Cally.TokenType.ERC721);

        // assert
        uint256 vaultIndex = c.vaultIndex();
        assertEq(vaultIndex, 7, "Should have incremented vaultIndex by 2");
        assertEq(vaultId1, 3, "Should have incremented vaultId by 2");
        assertEq(vaultId2, 5, "Should have incremented vaultId by 2");
        assertEq(vaultId3, 7, "Should have incremented vaultId by 2");
    }
}
