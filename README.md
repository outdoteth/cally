# Cally

**NFT and ERC20 covered call vaults**

![Github Actions](https://github.com/foundry-rs/forge-template/workflows/Tests/badge.svg)

## Installation

```
git clone https://github.com/outdoteth/cally
forge install
```

## Testing

```
forge test
```

---

## Description

Cally lets you create covered call vaults on any ERC20 or ERC721.
A user specificies their desired premium, and duration (days) of each call they would like to sell.
Every time the duration period passes, the option inside of the vault is put up for auction.
The auction starts at a max strike price set by the vault owner initially and then decreases to 0 over time.

Regular example:

- Alice creates vault with 0.1 ETH premium, 30 day duration on her BAYC, max strike of 500 ETH
- Auction starts at a strike of 500 ETH and decreases to 0 ETH over a 24 hour auction period
- Bob buys the call for 0.1 ETH, 30 day duration at a strike of 170 ETH after `T` amount of time has passed

  a)

  - After 30 days Bob's option expires out of the money
  - The option is automatically put up for auction again with the same parameters (0.1 ETH premium, 30 day duration, BAYC, max strike 500 ETH)

  b)

  - Bob exercises his option after 23 days
  - He sends and credits 170 ETH (strike amount) to Alice and the BAYC is sent to him
  - His option is burned and Alice's vault is marked as `isExercised` and is stopped from starting any more auctions

At any point Alice can `harvest` her uncollected premiums.
If the option has been exercised then she can `harvest` her 170 strike ETH too.
If Alice wants to `withdraw` her underlying assets (ERC721/ERC20) and close her vault, then she has to initiate a withdrawal first and then wait for the currently active option to expire.

Withdrawal example:

- Alice creates vault with 0.1 ETH premium, 30 day duration on her BAYC, max strike of 500 ETH
- Auction starts at a strike of 500 ETH and decreases to 0 ETH over a 24 hour auction period
- Bob buys the call for 0.1 ETH, 30 day duration at a strike of 170 ETH after `T` amount of time has passed
- Alice initiates a withdrawal
- Bob's option expires out of the money
- Auction is _not_ automatically started again
- Alice can `withdraw` her BAYC and burn her vault

---

## Notes

**There are various optimiztions that may make the contracts harder to reason about.
These are done to reduce gas cost burden on the user but at the cost of code readability.**

## Premium and strike indexing

To save gas, the details of each vault are represented as a struct with packed variables. To reduce storage costs, `premium` and `dutchAuctionStartingStrike` are uint8 indexes.
They index to:

```
premiumOptions = [0.01 ether, 0.025 ether, ... 100 ether]
strikeOptions = [1 ether, 2 ether, ... 6765 ether]
```

This means that instead of storing a `uint256` for the strike and premium values, we can just store a single `uint8`. Obviously the cost here is flexibility since a user is limited to our predefined set of strike/premium options.

## Automatic auction starting

Auctions are automatically started without anyone having to call a method such as `startAuction` or something similar.
If the expiration timestamp on the currently active option is less than the `block.timestamp` then the auction has started.
The start time of the auction is the expiration timestamp.
When a vault is _first_ created, the expiration timestamp is set to the current timestamp; this ensures that the auction is immediately started.
Whenever a user buys a new option the expiration is set to `block.timestamp + duration`.
Maybe a nice intuition: `expirationTimestamp == auctionStartTimestamp`

## Vault ID and Option ID

When a user creates a vault they are given a vault NFT.
When a user buys an option, they are given the associated vault's option NFT (1 per vault).
Vault token ID's are always odd. And option token ID's are always even `optionId = associatedVaultId + 1`.
Each vault NFT has 1 associated option NFT which is forcefully transferred between the old owner -> new owner whenever they buy an option from the vault auction.

## Removing balanceOf

All balanceOf modifications have been removed from the Cally NFTs.
This saves up to 20k gas when minting a vault NFT or buying an option NFT.
Given our use-case, it is a reasonable tradeoff.
The `balanceOf` for each user is set to be defaulted to `type(uint256).max` instead of `0`.
