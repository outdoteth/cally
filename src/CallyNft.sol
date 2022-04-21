// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "solmate/tokens/ERC721.sol";

// removes balanceOf modifications
// questionable tradeoff but given our use-case it's reasonable
// saves 20k gas when minting which about 30% gas on buys/vault creations
contract CallyNft is ERC721("Cally", "CALL") {
    string public baseURI;

    // remove balanceOf modifications
    function _mint(address to, uint256 id) internal override {
        require(to != address(0), "INVALID_RECIPIENT");
        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    // burns a token without checking owner address is not 0
    // and removes balanceOf modifications
    function _burn(uint256 id) internal override {
        address owner = _ownerOf[id];

        delete _ownerOf[id];
        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    // set balanceOf to max for all users
    function balanceOf(address owner) public pure override returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");
        return type(uint256).max;
    }

    // forceTransfer option position NFT out of owner's wallet and give to new buyer
    function _forceTransfer(address to, uint256 id) internal {
        require(to != address(0), "INVALID_RECIPIENT");

        address from = _ownerOf[id];
        _ownerOf[id] = to;
        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf[tokenId] != address(0), "URI query for NOT_MINTED token");
        return string(abi.encodePacked(baseURI, tokenId));
    }
}
