# Smart Contracts

This folder hosts all the smart contract source code, including zkLend contracts and dependencies.

## System overview

Here's a high-level diagram of the system architecture, including non-smart-contract components:

<p align="center">
  <img src="../images/system-overview.svg?raw=true" alt="System overview"/>
</p>

At the center of the system is the [Market](./zklend/Market.cairo) contract, which serves as the entrypoint for most user operations. It maintains user data, enforces invariants, and communicates with other smart contracts.

Another contract that users would often interact with is the [ZToken](./zklend/ZToken.cairo) contract, which is essentially an interest-bearing deposit certificate for assets deposited into the system. It's ERC20-compliant but unlike most ERC20 tokens with static balances, ZToken balances grow over time as interest accures such that it can always be exchanged 1:1 against the underlying asset.

The remaining two contracts that get deployed are the [PriceOracle](./zklend/PriceOracle.cairo) and [DefaultInterestRateModel](./zklend/irms/DefaultInterestRateModel.cairo), which are implementation details that users do not directly interface with.

## Upgradeability

To enable rapid iteration during the early stage of the protocol, some smart contracts have been designed to be upgradeable, specifically:

- [Market](./zklend/Market.cairo)
- [ZToken](./zklend/ZToken.cairo)

When these contracts are deployed, their classes are first declared, which will then be used as implementation classes inside the [Proxy](./zklend/Proxy.cairo) contract. Technically speaking, these upgradeable contracts are never really _deployed_, but only _declared_.

The rest of the contracts are immutable as they tend to hold a small state, making them trivial to be redeployed altogether.

For upgradeable contracts, the upgrade admin will be initially set to a timelock contract controlled by the zkLend team. The timelock contract should eventually be replaced by a governance contract controlled by a DAO, who will decide whether to keep the upgradeability or simply make the protocol immutable.
