// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "solmate/utils/SafeTransferLib.sol";
import "solmate/utils/ReentrancyGuard.sol";

import "./ICally.sol";
import "./CallyNft.sol";

contract Cally is CallyNft, ReentrancyGuard {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address payable;

    enum TokenType {
        ERC721,
        ERC20
    }

    struct Vault {
        uint256 tokenIdOrAmount;
        address token;
        uint8 premium;
        uint8 durationDays;
        uint8 dutchAuctionStartingStrike;
        uint8 dutchAuctionEndingStrike;
        bool isExercised;
        bool isWithdrawing;
        TokenType tokenType;
        uint32 currentExpiration;
        uint256 currentStrike;
    }

    uint32 public constant AUCTION_DURATION = 24 hours;
    ERC20 public immutable weth;

    // prettier-ignore
    uint256[] public premiumOptions = [0.01 ether, 0.025 ether, 0.05 ether, 0.075 ether, 0.1 ether, 0.25 ether, 0.5 ether, 0.75 ether, 1.0 ether, 2.5 ether, 5.0 ether, 7.5 ether, 10 ether, 25 ether, 50 ether, 75 ether, 100 ether];
    // prettier-ignore
    uint256[] public strikeOptions = [1 ether, 2 ether, 3 ether, 5 ether, 8 ether, 13 ether, 21 ether, 34 ether, 55 ether, 89 ether, 144 ether, 233 ether, 377 ether, 610 ether, 987 ether, 1597 ether, 2584 ether, 4181 ether, 6765 ether];

    uint256 public vaultIndex = 1;

    mapping(uint256 => Vault) private _vaults;
    mapping(address => uint256) public ethBalance;

    constructor(string memory baseURI_, address weth_) {
        baseURI = baseURI_;
        weth = ERC20(weth_);
    }

    function vaults(uint256 vaultId) public view returns (Vault memory) {
        return _vaults[vaultId];
    }

    function createVault(
        uint256 tokenIdOrAmount,
        address token,
        uint8 premium,
        uint8 durationDays,
        uint8 dutchAuctionStartingStrike,
        uint8 dutchAuctionEndingStrike,
        TokenType tokenType
    ) external returns (uint256 vaultId) {
        Vault memory vault = Vault({
            tokenIdOrAmount: tokenIdOrAmount,
            token: token,
            premium: premium,
            durationDays: durationDays,
            dutchAuctionStartingStrike: dutchAuctionStartingStrike,
            dutchAuctionEndingStrike: dutchAuctionEndingStrike,
            currentExpiration: uint32(block.timestamp),
            isExercised: false,
            isWithdrawing: false,
            tokenType: tokenType,
            currentStrike: 0
        });

        // vault index should always be odd
        vaultIndex += 2;
        vaultId = vaultIndex;
        _vaults[vaultId] = vault;

        // give msg.sender vault token
        _mint(msg.sender, vaultId);

        // transfer the NFTs or ERC20s to the contract
        vault.tokenType == TokenType.ERC721
            ? ERC721(vault.token).transferFrom(msg.sender, address(this), vault.tokenIdOrAmount)
            : ERC20(vault.token).safeTransferFrom(msg.sender, address(this), vault.tokenIdOrAmount);
    }

    function getPremium(uint256 vaultId) public view returns (uint256 premium) {
        Vault memory vault = _vaults[vaultId];
        return premiumOptions[vault.premium];
    }

    // strike decreases linearly to 0 over time starting at dutchAuctionStartingStrike
    function getDutchAuctionStrike(uint256 vaultId) public view returns (uint256 currentStrike) {
        Vault memory vault = _vaults[vaultId];

        // TODO: change this
        /*
            delta = auctionEnd - currentTimestamp
            progress = delta / auctionDuration
            strike = progress^2 * startingStrike
        */

        // strike = (startingStrike * max(end - current, 0)) / auctionDuration
        uint32 auctionEndTimestamp = vault.currentExpiration + AUCTION_DURATION;
        uint256 startingStrike = strikeOptions[vault.dutchAuctionStartingStrike];
        uint32 delta = uint32(block.timestamp) < auctionEndTimestamp
            ? auctionEndTimestamp - uint32(block.timestamp)
            : 0;

        currentStrike = (startingStrike * delta) / AUCTION_DURATION;
    }

    function buyOption(uint256 vaultId) external payable returns (uint256 optionId) {
        Vault memory vault = _vaults[vaultId];

        // check that the vault still has the NFTs as collateral
        require(vault.isExercised == false, "Vault already exercised");

        // check that the vault is not in withdrawing state
        require(vault.isWithdrawing == false, "Vault is being withdrawn");

        // check option has expired
        uint32 auctionStartTimestamp = vault.currentExpiration;
        require(block.timestamp >= auctionStartTimestamp, "Auction not started");

        // check enough eth was sent to cover premium
        uint256 premium = getPremium(vaultId);
        require(msg.value == premium, "Incorrect ETH amount sent");

        // set new currentStrike and expiration
        vault.currentExpiration = uint32(block.timestamp) + (vault.durationDays * 1 days);
        vault.currentStrike = getDutchAuctionStrike(vaultId);
        _vaults[vaultId] = vault;

        // force transfer the expired option from old owner to new owner
        // option id is for a respective vault is always vaultId + 1
        optionId = vaultId + 1;
        _forceTransfer(msg.sender, optionId);

        // increment vault owner's unclaimed premiums
        address vaultOwner = ownerOf(vaultId);
        ethBalance[vaultOwner] += msg.value;
    }

    function exercise(uint256 optionId) external payable {
        // check owner
        require(msg.sender == ownerOf(optionId), "You are not the owner");

        uint256 vaultId = optionId - 1;
        Vault memory vault = _vaults[vaultId];

        // check option hasn't expired
        require(block.timestamp < vault.currentExpiration, "Option has expired");

        // check correct ETH amount was sent to pay the strike
        require(msg.value == vault.currentStrike, "Incorrect ETH sent for strike");

        // burn the option token
        _burn(optionId);

        // mark the vault as expired
        vault.isExercised = true;
        _vaults[vaultId] = vault;

        // Increment vault owner's ETH balance
        ethBalance[ownerOf(vaultId)] += msg.value;

        // transfer the NFTs or ERC20s to the buyer
        vault.tokenType == TokenType.ERC721
            ? ERC721(vault.token).transferFrom(address(this), msg.sender, vault.tokenIdOrAmount)
            : ERC20(vault.token).safeTransfer(msg.sender, vault.tokenIdOrAmount);
    }

    function initiateWithdraw(uint256 vaultId) external {
        require(msg.sender == ownerOf(vaultId), "You are not the owner");
        _vaults[vaultId].isWithdrawing = true;
    }

    function withdraw(uint256 vaultId) external nonReentrant {
        // check owner
        require(msg.sender == ownerOf(vaultId), "You are not the owner");

        Vault memory vault = _vaults[vaultId];

        // check vault can be withdrawn
        require(vault.isExercised == false, "Vault already exercised");
        require(vault.isWithdrawing, "Vault not in withdrawable state");
        require(block.timestamp > vault.currentExpiration, "Option still active");

        // claim any ETH still in the account
        harvest(vaultId);

        // burn option and vault
        uint256 optionId = vaultId + 1;
        _burn(optionId);
        _burn(vaultId);

        // transfer the NFTs or ERC20s back to the owner
        vault.tokenType == TokenType.ERC721
            ? ERC721(vault.token).transferFrom(address(this), msg.sender, vault.tokenIdOrAmount)
            : ERC20(vault.token).safeTransfer(msg.sender, vault.tokenIdOrAmount);
    }

    function harvest(uint256 vaultId) public returns (uint256 amount) {
        address vaultOwner = ownerOf(vaultId);
        require(msg.sender == vaultOwner, "You are not the owner");

        // reset premiums
        amount = ethBalance[vaultOwner];
        ethBalance[vaultOwner] = 0;

        // transfer premiums to owner
        payable(msg.sender).safeTransferETH(amount);
    }
}
