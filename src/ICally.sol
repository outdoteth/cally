// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ICally {
    event NewVault(uint256 indexed vaultId, address indexed from, address indexed token);
    event BoughtOption(uint256 indexed optionId, address indexed from, address indexed token);
    event ExercisedOption(uint256 indexed optionId, address indexed from);
    event Harvested(address indexed from, uint256 amount);
    event InitiatedWithdrawal(uint256 indexed vaultId, address indexed from);
    event Withdrawal(uint256 indexed vaultId, address indexed from);

    struct Vault {
        uint256 tokenIdOrAmount;
        address token;
        uint8 premium;
        uint8 durationDays;
        uint8 dutchAuctionStartingStrike;
        bool isExercised;
        bool isWithdrawing;
        TokenType tokenType;
        uint32 currentExpiration;
        uint256 currentStrike;
    }

    enum TokenType {
        ERC721,
        ERC20
    }

    function createVault(
        uint256 tokenIdOrAmount,
        address token,
        uint8 premium,
        uint8 durationDays,
        uint8 dutchAuctionStartingStrike,
        TokenType tokenType
    ) external returns (uint256 vaultId);

    function buyOption(uint256 vaultId) external payable returns (uint256 optionId);

    function exercise(uint256 optionId) external payable;

    function initiateWithdraw(uint256 vaultId) external;

    function withdraw(uint256 vaultId) external;

    function setVaultBeneficiary(uint256 vaultId, address beneficiary) external;

    function harvest() external returns (uint256 amount);

    function getVaultBeneficiary(uint256 vaultId) external view returns (address beneficiary);

    function vaults(uint256 vaultId) external view returns (Vault memory);

    function getPremium(uint256 vaultId) external view returns (uint256 premium);

    function getDutchAuctionStrike(uint256 startingStrike, uint32 auctionEndTimestamp)
        external
        view
        returns (uint256 strike);
}
