# Cally

**NFT and ERC20 covered call vaults**

![Github Actions](https://github.com/foundry-rs/forge-template/workflows/Tests/badge.svg)

## Installation

Clone the repo and then run:

```
forge install
```

## Testing

```
forge test
```

## Links

Rinkeby demo site: https://rinkeby.cally.finance

Rinkeby etherscan: https://rinkeby.etherscan.io/address/0xfccf2ee317f46d032a3a70dccffc311db499921f#code

Twitter: https://twitter.com/callyfinance

Discord: https://discord.gg/rxppJYj4Jp

## Contracts Overview

| Name             | LOC | Purpose                                                     |
| ---------------- | --- | ----------------------------------------------------------- |
| **Cally.sol**    | 219 | Entry point to the protocol. Holds the business logic.      |
| **CallyNft.sol** | 220 | NFT contract to represent Cally vault and option positions. |

## High level flow overview

A user specificies their desired premium, and duration (days) of each call they would like to sell.
Every time the duration period passes, the option inside of the vault is put up for auction.
The auction starts at a max strike price set by the vault owner initially and then decreases to 0 over time.

Regular example:

- Alice creates vault with 0.1 ETH premium, 30 day duration on her BAYC, max strike of 500 ETH
- Dutch auction starts at a strike of 500 ETH and decreases to 0 ETH over a 24 hour auction period
- Bob buys the call for 0.1 ETH, 30 day duration at a strike of 164.3 ETH after `T` amount of time has passed

  either a)

  - Bob exercises his option after 23 days
  - He sends 164.3 ETH (strike amount) to the contract and the BAYC is sent to him. The 164.3 ETH is credited to Alice
  - His option is burned and Alice's vault is marked as `isExercised` and is stopped from starting any more auctions

  or b)

  - After 30 days Bob's option expires out of the money and he has chosen not to exercise
  - The option is automatically put up for auction again with the same parameters (0.1 ETH premium, 30 day duration, BAYC, max strike 500 ETH)

At any point Alice can `harvest` her uncollected premiums.
If the option has been exercised then she can `harvest` the 164.3 strike ETH too.
If Alice wants to `withdraw` her underlying assets (ERC721/ERC20) and close her vault, then she has to initiate a withdrawal first and then wait for the currently active option to expire.

Flow diagram:

```
                      (Alice)
                 ┌────────────────┐
                 │                │
                 │   NFT holder   │
                 │                │
                 └───────┬────────┘
                         │
          1.Create vault │
            + deposit    │
            NFT          │
                         │
                         │                   4.Transfer option
                         │                     from old trader        (Bob)
              ┌──────────▼──────────────────┐  to new trader   ┌────────────────┐
              │                             ├──────────────────►                │
              │          Cally.sol          │                  │     Trader     │
              │                             ◄──────────────────┤                │
              └─────────────────────────────┘ 3.Send premium   └────────────────┘
                     2.Start auction            ETH and buy
    ┌──────────────► for call option            option at the
    │                                           current auction
    │                                           strike
    │
    │
    │      *Some time passes*
    │
    │         Flow (a): Trader decides to exercise
    │         ....................................
    │
    │
    │               6a.Credit ETH to
    │               beneficiary of the
    │               vault                      5a.Exercise and         (Bob)
    │         ┌─────────────────────────────┐  send strike ETH  ┌────────────────┐
    │         │                             ◄───────────────────┤                │
    │         │          Cally.sol          │                   │     Trader     │
    │         │                             ├───────────────────►                │
    │         └─────────────────────────────┘    7a.Send NFT    └────────────────┘
    │                                            to trader
    │
    │
    │      *Option duration time passes*
    │
    │         Flow (b): Trader decides to let option expire
    │         .............................................
    │
    │
    │         ┌─────────────────────────────┐
    │         │                             │
    └─────────┤          Cally.sol          │
5b.Auction is │                             │
automatically └─────────────────────────────┘
restarted for
a new option
```

Withdrawal example:

Alice can also initiate a withdrawal on her vault and get her NFT back. This is the flow for withdrawals:

- Alice creates vault with 0.1 ETH premium, 30 day duration on her BAYC, max strike of 500 ETH
- Auction starts at a strike of 500 ETH and decreases to 0 ETH over a 24 hour auction period
- Bob buys the call for 0.1 ETH, 30 day duration at a strike of 164.3 ETH after `T` amount of time has passed
- Alice initiates a withdrawal (`initiateWithdraw`)
- Bob's option expires out of the money after 30 days
- Auction is _not_ automatically started again because Alice's vault `isWithdrawing`
- Alice can `withdraw` her BAYC and burn her vault

---

## Novel curve logic/mathematical models

### Quadratically decreasing dutch auction with a reserve price

Every time an option expires, a dutch auction is started for the strike price of the _new_ option being sold following a quadratic curve.
The input parameters are `startingStrike`, `auctionDuration`, `auctionEndTimestamp`, `reserveStrike`. To get the current strike price in the auction:

```
delta = max(auctionEndTimestamp - currentTimestamp, 0)
progress = delta / auctionDuration
strike = (progress^2 * (startingStrike - reserveStrike)) + reserveStrike
```

for example using the following parameters:

```
startingStrike = 26 ETH
reserveStrike = 2.6 ETH
```

yields an auction curve for the strike price that like this (https://www.desmos.com/calculator/omwlvxy3ed):

![auction graph](./assets/auction-graph.png)

---

## Libraries

- [solmate/utils/SafeTransferLib.sol](https://github.com/code-423n4/2022-05-cally/blob/main/contracts/lib/solmate/src/utils/SafeTransferLib.sol)

- [solmate/utils/ReentrancyGuard.sol](https://github.com/code-423n4/2022-05-cally/blob/main/contracts/lib/solmate/src/utils/ReentrancyGuard.sol)

- [openzeppelin/access/Ownable.sol](https://github.com/code-423n4/2022-05-cally/blob/main/contracts/lib/openzeppelin-contracts/contracts/access/Ownable.sol)

- [solmate/tokens/ERC721.sol](https://github.com/code-423n4/2022-05-cally/blob/main/contracts/lib/solmate/src/tokens/ERC721.sol)

- [openzeppelin/utils/Strings.sol](https://github.com/code-423n4/2022-05-cally/blob/main/contracts/lib/openzeppelin-contracts/contracts/utils/Strings.sol)

- [hot-chain-svg/SVG.sol](https://github.com/code-423n4/2022-05-cally/blob/main/contracts/lib/hot-chain-svg/contracts/SVG.sol)

- [base64/base64.sol](https://github.com/code-423n4/2022-05-cally/blob/main/contracts/lib/base64/base64.sol)

---

## Notes

**There are various optimizations that may make the contracts harder to reason about.
These are done to reduce gas costs but at the expense of code readability. Here are some helpful explanations of those optimizations.**

### Premium and strike indexing

To save gas, the details of each vault are represented as a struct with packed variables. To reduce storage costs, `premium` and `dutchAuctionStartingStrike` are uint8 indexes.
They index to:

```solidity
uint256[] public premiumOptions = [0.01 ether, 0.025 ether, ... 100 ether]
uint256[] public strikeOptions = [1 ether, 2 ether, ... 6765 ether]
```

This means that instead of storing a `uint256` for the strike and premium values, we can just store a single `uint8` index that references one of those options in the array. The cost here is flexibility since a user is limited to our predefined set of starting strike/premium options.

### Automatic auction starting

Auctions are automatically started without anyone having to call a method such as `startAuction` or something similar.
If the `block.timestamp` is greater than the current expiration of the vault's option then the auction has started.
This is the key condition.
The start time of the auction is the expiration timestamp.
When a vault is _first_ created, the expiration timestamp is set to the current timestamp; this ensures that the auction is immediately started.
Whenever a user buys a new option the expiration for the option in the vault is set to `block.timestamp + duration`.
Maybe a nice intuition: `expirationTimestamp == auctionStartTimestamp`

### Vault ID and Option ID

When a user creates a vault they are given a vault NFT.
When a user buys an option, they are given the associated vault's option NFT (1 per vault).
Vault token ID's are always odd. And option token ID's are always even `optionId = associatedVaultId + 1`.
Each vault NFT has 1 associated option NFT which is forcefully transferred between the old owner -> new owner whenever they buy an option from the vault auction.

### Removing balanceOf

Cally creates NFTs for each vault and option.
All balanceOf modifications have been removed from the Cally NFTs.
Given our use-case, it is a reasonable tradeoff.
The `balanceOf` for each user is set to be defaulted to `type(uint256).max` instead of `0`.

```solidity
function balanceOf(address owner) public pure override returns (uint256) {
  require(owner != address(0), "ZERO_ADDRESS");
  return type(uint256).max; // return max for all accounts
}

```

This was done to save gas since not tracking the `balanceOf` avoids a single storage modification or initialisation on each transfer/mint/burn.
