# Smart Contracts

This folder hosts all the zkLend smart contract source code. zkLend smart contracts do not use any external dependencies.

## System overview

Here's a high-level diagram of the system architecture, including non-smart-contract components:

<p align="center">
  <img src="../images/system-overview.svg?raw=true" alt="System overview"/>
</p>

At the center of the system is the [Market](./market.cairo) contract, which serves as the entrypoint for most user operations. It maintains user data, enforces invariants, and communicates with other smart contracts.

Another contract that users would often interact with is the [ZToken](./z_token.cairo) contract, which is essentially an interest-bearing deposit certificate for assets deposited into the system. It's ERC20-compliant but unlike most ERC20 tokens with static balances, ZToken balances grow over time as interest accures such that it can always be exchanged 1:1 against the underlying asset.

The remaining two contracts that get deployed are the [DefaultPriceOracle](./default_price_oracle.cairo) and [DefaultInterestRateModel](./irms/default_interest_rate_model.cairo), which are implementation details that users do not directly interface with.

## Upgradeability

To enable rapid iteration during the early stage of the protocol, some smart contracts have been designed to be upgradeable, specifically:

- [Market](./market.cairo)
- [ZToken](./z_token.cairo)

The upgradeability is enabled by the `replace_class` syscall. Thanks to the syscall, there's no need to use the proxy pattern at all, as the contract itself can change its own implementation.

The rest of the contracts are immutable as they tend to hold a small state, making them trivial to be redeployed altogether.

For upgradeable contracts, the upgrade admin will be initially set to a timelock contract controlled by the zkLend team. The timelock contract should eventually be replaced by a governance contract controlled by a DAO, who will decide whether to keep the upgradeability or simply make the protocol immutable.
