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

    // prettier-ignore
    uint256[] public premiumOptions = [0.01 ether, 0.025 ether, 0.05 ether, 0.075 ether, 0.1 ether, 0.25 ether, 0.5 ether, 0.75 ether, 1.0 ether, 2.5 ether, 5.0 ether, 7.5 ether, 10 ether, 25 ether, 50 ether, 75 ether, 100 ether];
    // prettier-ignore
    uint256[] public strikeOptions = [1 ether, 2 ether, 3 ether, 5 ether, 8 ether, 13 ether, 21 ether, 34 ether, 55 ether, 89 ether, 144 ether, 233 ether, 377 ether, 610 ether, 987 ether, 1597 ether, 2584 ether, 4181 ether, 6765 ether];
    uint32 public constant AUCTION_DURATION = 24 hours;

    ERC20 public immutable weth;
    string public baseURI;

    uint256 public vaultIndex = 1;
    mapping(uint256 => Vault) private _vaults;

    constructor(address weth_, string memory baseURI_) {
        weth = ERC20(weth_);
        baseURI = baseURI_;
    }

    function vaults(uint256 vaultId) public view returns (Vault memory) {
        return _vaults[vaultId];
    }

    // ignore balanceOf to save 20k gas
    // questionable tradeoff but should be ok for our case
    function _mint(address to, uint256 id) internal override {
        require(to != address(0), "INVALID_RECIPIENT");
        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    // set balanceOf to max for all users
    function balanceOf(address owner) public pure override returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");
        return type(uint256).max;
    }

    function _forceTransfer(address to, uint256 id) internal {
        require(to != address(0), "INVALID_RECIPIENT");

        address from = _ownerOf[id];
        _ownerOf[id] = to;
        delete getApproved[id];

        emit Transfer(from, to, id);
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
        _vaults[vaultId] = vault;

        // give msg.sender vault token
        _mint(msg.sender, vaultId);

        // transfer the underlying NFTs to the contract
        ERC721(vault.token).transferFrom(msg.sender, address(this), vault.tokenId);
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

    function buyOption(uint256 vaultId) external returns (uint256 optionId) {
        Vault memory vault = _vaults[vaultId];

        // check that the vault still has the NFTs as collateral
        require(vault.isExercised == false, "Vault already exercised");

        // check that the vault is not in withdrawing state
        require(vault.isWithdrawing == false, "Vault is being withdrawn");

        // check option has expired
        uint32 auctionStartTimestamp = vault.currentExpiration;
        require(block.timestamp >= auctionStartTimestamp, "Auction not started");

        // set new currentStrike and expiration
        vault.currentExpiration = uint32(block.timestamp) + (vault.durationDays * 1 days);
        vault.currentStrike = getDutchAuctionStrike(vaultId);
        _vaults[vaultId] = vault;

        // force transfer expired option to new owner
        // option id is for a respective vault is always vaultId + 1
        optionId = vaultId + 1;
        _forceTransfer(msg.sender, optionId);

        // pay premium
        uint256 premium = premiumOptions[vault.premium];
        weth.transferFrom(msg.sender, ownerOf(vaultId), premium);
    }

    function exercise(uint256 optionId) external {
        // check owner
        require(msg.sender == ownerOf(optionId), "You are not the owner");

        uint256 vaultId = optionId - 1;
        Vault memory vault = _vaults[vaultId];

        // check option hasn't expired
        require(block.timestamp < vault.currentExpiration, "Option has expired");

        // burn the optionId
        _burn(optionId);

        // mark the vault as expired
        vault.isExercised = true;
        _vaults[vaultId] = vault;

        // transfer the WETH to vault owner
        weth.transferFrom(msg.sender, ownerOf(vaultId), vault.currentStrike);

        // transfer the NFTs to the buyer
        ERC721(vault.token).transferFrom(address(this), msg.sender, vault.tokenId);
    }

    function initiateWithdraw(uint256 vaultId) external {
        require(msg.sender == ownerOf(vaultId), "You are not the owner");
        _vaults[vaultId].isWithdrawing = true;
    }

    function withdraw(uint256 vaultId) external {
        // check owner
        require(msg.sender == ownerOf(vaultId), "You are not the owner");

        Vault memory vault = _vaults[vaultId];

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
