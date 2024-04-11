use traits::Into;

use starknet::ContractAddress;

// Hack to simulate the `crate` keyword
use super::super as crate;

use crate::libraries::safe_decimal_math;

use super::internal;

use super::ZToken as contract;

use contract::ContractState;

// These are hacks that depend on compiler implementation details :(
// But they're needed for refactoring the contract code into modules like this one.
use contract::allowancesContractMemberStateTrait;
use contract::raw_balancesContractMemberStateTrait;
use contract::raw_total_supplyContractMemberStateTrait;
use contract::token_decimalsContractMemberStateTrait;
use contract::token_nameContractMemberStateTrait;
use contract::token_symbolContractMemberStateTrait;
use contract::underlyingContractMemberStateTrait;

fn name(self: @ContractState) -> felt252 {
    self.token_name.read()
}

fn symbol(self: @ContractState) -> felt252 {
    self.token_symbol.read()
}

fn decimals(self: @ContractState) -> felt252 {
    self.token_decimals.read()
}

fn totalSupply(self: @ContractState) -> u256 {
    felt_total_supply(self).into()
}

fn felt_total_supply(self: @ContractState) -> felt252 {
    let accumulator = internal::get_accumulator(self);

    let supply = self.raw_total_supply.read();
    let scaled_up_supply = safe_decimal_math::mul(supply, accumulator);

    scaled_up_supply
}

fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
    felt_balance_of(self, account).into()
}

fn felt_balance_of(self: @ContractState, account: ContractAddress) -> felt252 {
    let accumulator = internal::get_accumulator(self);

    let balance = self.raw_balances.read(account);
    let scaled_up_balance = safe_decimal_math::mul(balance, accumulator);

    scaled_up_balance
}

fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
    felt_allowance(self, owner, spender).into()
}

fn felt_allowance(
    self: @ContractState, owner: ContractAddress, spender: ContractAddress
) -> felt252 {
    self.allowances.read((owner, spender))
}

fn underlying_token(self: @ContractState) -> ContractAddress {
    self.underlying.read()
}

fn get_raw_total_supply(self: @ContractState) -> felt252 {
    self.raw_total_supply.read()
}
