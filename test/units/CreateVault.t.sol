// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../shared/Fixture.t.sol";
import "src/Cally.sol";

contract TestCreateVault is Test, Fixture {
    event NewVault(uint256 indexed vaultId, address indexed from, address indexed token);

    function setUp() public {
        bayc.mint(address(this), 1);
        bayc.mint(address(this), 2);
        bayc.mint(address(this), 100);
        bayc.setApprovalForAll(address(c), true);
    }

    function testItEmitsNewVaultEvent() public {
        // act
        vm.expectEmit(true, true, true, false);
        emit NewVault(3, address(this), address(bayc));
        c.createVault(1, address(bayc), 2, 1, 0, 0, Cally.TokenType.ERC721);
    }

    function testItSendsERC721ForCollateral() public {
        // act
        c.createVault(1, address(bayc), 2, 1, 0, 0, Cally.TokenType.ERC721);

        // assert
        assertEq(bayc.balanceOf(address(c)), 1, "Should have sent BAYC to Cally");
        assertEq(bayc.ownerOf(1), address(c), "Should have sent BAYC to Cally");
    }

    function testItSendsERC20ForCollateral() public {
        // arrange
        uint256 amount = 1337;
        link.mint(address(this), amount);
        link.approve(address(c), amount);
        uint256 balanceBefore = link.balanceOf(address(this));

        // act
        uint256 vaultId = c.createVault(amount, address(link), 2, 1, 0, 0, Cally.TokenType.ERC20);
        uint256 change = balanceBefore - link.balanceOf(address(this));

        // assert
        assertEq(link.balanceOf(address(c)), amount, "Should have sent LINK to Cally");
        assertEq(change, amount, "Should have sent LINK from account");
        assertEq(c.vaults(vaultId).tokenIdOrAmount, change, "Should have set vault tokenIdOrAmount");
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
        uint8 premiumIndex = 2;
        uint8 durationDays = 3;
        uint8 dutchAuctionStartingStrikeIndex = 3;
        uint256 dutchAuctionReserveStrike = 0.1 ether;
        Cally.TokenType tokenType = Cally.TokenType.ERC721;

        // act
        uint256 vaultId = c.createVault(
            tokenId,
            token,
            premiumIndex,
            durationDays,
            dutchAuctionStartingStrikeIndex,
            dutchAuctionReserveStrike,
            tokenType
        );

        // assert
        Cally.Vault memory vault = c.vaults(vaultId);
        assertEq(vault.tokenIdOrAmount, tokenId, "Should have set tokenId");
        assertEq(vault.token, token, "Should have set token");
        assertEq(vault.premiumIndex, premiumIndex, "Should have set premium index");
        assertEq(vault.durationDays, durationDays, "Should have set durationDays");
        assertEq(
            vault.dutchAuctionStartingStrikeIndex,
            dutchAuctionStartingStrikeIndex,
            "Should have set starting strike"
        );
        assertEq(vault.dutchAuctionReserveStrike, dutchAuctionReserveStrike, "Should have set reserve strike");
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

    function testItCannotCreateVaultWithInvalidPremium() public {
        // act
        vm.expectRevert("Invalid premium index");
        c.createVault(1, address(bayc), 150, 1, 0, 0, Cally.TokenType.ERC721);
    }

    function testItCannotCreateVaultWithInvalidStrike() public {
        // act
        vm.expectRevert("Invalid strike index");
        c.createVault(1, address(bayc), 1, 12, 150, 0, Cally.TokenType.ERC721);
    }

    function testItCannotCreateVaultWithInvalidReserveStrike() public {
        // act
        vm.expectRevert("Reserve strike too large");
        c.createVault(1, address(bayc), 1, 12, 2, 1000 ether, Cally.TokenType.ERC721);
    }

    function testItCannotCreateVaultWithInvalidDurationDays() public {
        // act
        vm.expectRevert("durationDays too small");
        c.createVault(1, address(bayc), 1, 0, 1, 0, Cally.TokenType.ERC721);
    }

    function testItCannotCreateVaultWithNonContractTokenAddress() public {
        // act
        vm.expectRevert("token is not contract");
        c.createVault(1, address(0xdeadbeef), 1, 1, 1, 0, Cally.TokenType.ERC20);
    }

    function testItCannotCreateVaultWithCallyNFTAsAsset() public {
        // arrange
        c.setApprovalForAll(address(c), true);

        // act
        vm.expectRevert("token cannot be Cally contract");
        c.createVault(3, address(c), 1, 1, 1, 0, Cally.TokenType.ERC721);
    }

    function testItCannotCreateVaultWith0ERC20Tokens() public {
        // act
        vm.expectRevert("tokenIdOrAmount is 0");
        c.createVault(0, address(link), 1, 1, 1, 0, Cally.TokenType.ERC20);
    }

    function testItCreatesVault(
        uint8 premiumIndex,
        uint8 durationDays,
        uint8 dutchAuctionStartingStrikeIndex
    ) public {
        vm.assume(premiumIndex < 17);
        vm.assume(durationDays > 0);
        vm.assume(dutchAuctionStartingStrikeIndex < 19);

        // act
        uint256 vaultId = c.createVault(
            1,
            address(bayc),
            premiumIndex,
            durationDays,
            dutchAuctionStartingStrikeIndex,
            0,
            Cally.TokenType.ERC721
        );

        // assert
        Cally.Vault memory vault = c.vaults(vaultId);
        assertEq(vault.tokenIdOrAmount, 1, "Should have set tokenId");
        assertEq(vault.token, address(bayc), "Should have set token");
        assertEq(vault.premiumIndex, premiumIndex, "Should have set premium index");
        assertEq(vault.durationDays, durationDays, "Should have set durationDays");
        assertEq(
            vault.dutchAuctionStartingStrikeIndex,
            dutchAuctionStartingStrikeIndex,
            "Should have set starting strike index"
        );
    }

    uint256[] internal tokenIdOrAmounts = [1, 2, 100];
    address[] internal tokens = [address(bayc), address(bayc), address(bayc)];
    uint8[] internal premiumIndexes = [1, 1, 1];
    uint8[] internal durationDays = [12, 12, 12];
    uint8[] internal dutchAuctionStartingStrikeIndexes = [1, 1, 1];
    uint256[] internal dutchAuctionReserveStrikes = [0, 0, 0];
    Cally.TokenType[] internal tokenTypes = [Cally.TokenType.ERC721, Cally.TokenType.ERC721, Cally.TokenType.ERC721];

    function testItCreatesMultipleVaults() public {
        // arrange
        tokens = [address(bayc), address(bayc), address(bayc)];

        // act
        uint256[] memory vaultIds = c.createVaults(
            tokenIdOrAmounts,
            tokens,
            premiumIndexes,
            durationDays,
            dutchAuctionStartingStrikeIndexes,
            dutchAuctionReserveStrikes,
            tokenTypes
        );

        // assert
        assertEq(vaultIds.length, tokenIdOrAmounts.length, "Length should be equal to passed in array");
        assertEq(vaultIds[0], 3, "Should have created first vault");
        assertEq(vaultIds[vaultIds.length - 1], 7, "Should have created last vault");
    }
}
