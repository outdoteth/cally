// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ICally.sol";
import "solmate/utils/SafeTransferLib.sol";
import "solmate/tokens/ERC721.sol";

contract Cally is ERC721("Cally", "CALL") {
    using SafeTransferLib for ERC20;

    struct Vault {
        uint256 tokenId;
        address token;
        uint8 premium;
        uint8 durationDays;
        uint8 dutchAuctionStartingStrike;
        uint8 dutchAuctionEndingStrike;
        bool isExercised;
        bool isWithdrawing;
        uint32 currentExpiration;
        uint256 currentStrike;
    }

    uint32 public constant AUCTION_DURATION = 24 hours;
    ERC20 public immutable weth;
    string public baseURI;

    uint256 public vaultIndex = 1;
    mapping(uint256 => Vault) public vaults;

    constructor(address weth_, string memory baseURI_) {
        weth = ERC20(weth_);
        baseURI = baseURI_;
    }

    // ignore balanceOf to save 20k gas
    // questionable tradeoff but should be ok for our case
    function _mint(address to, uint256 id) internal override {
        require(to != address(0), "INVALID_RECIPIENT");
        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    // set balanceOf to 1 for all users
    function balanceOf(address owner) public pure override returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");
        return 1;
    }

    function createVault(
        uint256 tokenId,
        address token,
        uint8 premium,
        uint8 durationDays,
        uint8 dutchAuctionStartingStrike,
        uint8 dutchAuctionEndingStrike
    ) external returns (uint256 vaultId) {
        Vault memory vault = Vault({
            tokenId: tokenId,
            token: token,
            premium: premium,
            durationDays: durationDays,
            dutchAuctionStartingStrike: dutchAuctionStartingStrike,
            dutchAuctionEndingStrike: dutchAuctionEndingStrike,
            currentExpiration: uint32(block.timestamp),
            isExercised: false,
            isWithdrawing: false,
            currentStrike: 0
        });

        // vault index should always be odd
        vaultIndex += 2;
        vaultId = vaultIndex;
        vaults[vaultId] = vault;

        // give msg.sender vault token
        _mint(msg.sender, vaultId);

        // transfer the underlying NFTs to the contract
        ERC721(vault.token).transferFrom(msg.sender, address(this), vault.tokenId);
    }

    function buyOption(uint256 vaultId) external returns (uint256 optionId) {
        Vault memory vault = vaults[vaultId];

        // check that the vault still has the NFTs as collateral
        require(vault.isExercised == false, "Vault already exercised");

        // check that the vault is not in withdrawing state
        require(vault.isWithdrawing == false, "Vault is being withdrawn");

        // check option has expired
        uint32 auctionStartTimestamp = vault.currentExpiration;
        uint32 auctionEndTimestamp = vault.currentExpiration + AUCTION_DURATION;
        require(block.timestamp >= auctionStartTimestamp, "Auction not started");

        // set new currentStrike and expiration
        // strike = (startingStrike * max(end - current, 0)) / auctionDuration
        uint32 delta = uint32(block.timestamp) < auctionEndTimestamp
            ? auctionEndTimestamp - uint32(block.timestamp)
            : 0;
        uint256 currentStrike = (vault.dutchAuctionStartingStrike * delta) / AUCTION_DURATION;
        vault.currentExpiration = uint32(block.timestamp) + (vault.durationDays * 1 days);
        vault.currentStrike = currentStrike;
        vaults[vaultId] = vault;

        // force transfer expired option to new owner
        // option id is for a respective vault is always vaultId + 1
        optionId = vaultId + 1;

        // TODO: change this to remove approvals too (use a function instead)
        _ownerOf[optionId] = msg.sender;

        // pay premium
        weth.transferFrom(msg.sender, ownerOf(vaultId), 100);
    }

    function exercise(uint256 optionId) external {
        // check owner
        require(msg.sender == ownerOf(optionId), "You are not the owner");

        uint256 vaultId = optionId - 1;
        Vault memory vault = vaults[vaultId];

        // check option hasn't expired
        require(block.timestamp < vault.currentExpiration, "Option has expired");

        // transfer the WETH to vault owner
        weth.transferFrom(msg.sender, ownerOf(vaultId), vault.currentStrike);

        // transfer the NFTs to the buyer
        ERC721(vault.token).transferFrom(address(this), msg.sender, vault.tokenId);

        // burn the optionId
        _burn(optionId);

        // mark the vault as expired
        vault.isExercised = true;
        vaults[vaultId] = vault;
    }

    function initiateWithdraw(uint256 vaultId) external {
        require(msg.sender == ownerOf(vaultId), "You are not the owner");
        vaults[vaultId].isWithdrawing = true;
    }

    function withdraw(uint256 vaultId) external {
        // check owner
        require(msg.sender == ownerOf(vaultId), "You are not the owner");

        Vault memory vault = vaults[vaultId];

        // check vault can be withdrawn
        require(vault.isExercised == false, "Vault already exercised");
        require(vault.isWithdrawing, "Vault not in withdrawable state");
        require(block.timestamp > vault.currentExpiration, "Option still active");

        // burn option and vault
        uint256 optionId = vaultId + 1;
        _ownerOf[optionId] = address(0);
        _burn(vaultId);

        // send NFTs back to owner
        ERC721(vault.token).transferFrom(address(this), msg.sender, vault.tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf[tokenId] != address(0), "URI query for NOT_MINTED token");
        return string(abi.encodePacked(baseURI, tokenId));
    }
}
