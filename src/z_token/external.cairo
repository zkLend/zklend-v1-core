use option::OptionTrait;
use traits::{Into, TryInto};
use zeroable::Zeroable;

use starknet::event::EventEmitter;
use starknet::{
    ClassHash, ContractAddress, SyscallResultTrait, contract_address_const, get_caller_address,
    replace_class_syscall
};

// Hack to simulate the `crate` keyword
use super::super as crate;

use crate::libraries::{ownable, safe_decimal_math, safe_math};

use super::traits::ZTokenOwnable;
use super::{errors, internal};

use super::ZToken as contract;

use contract::ContractState;

// These are hacks that depend on compiler implementation details :(
// But they're needed for refactoring the contract code into modules like this one.
use contract::allowancesContractMemberStateTrait;
use contract::marketContractMemberStateTrait;
use contract::raw_balancesContractMemberStateTrait;
use contract::raw_total_supplyContractMemberStateTrait;
use contract::token_decimalsContractMemberStateTrait;
use contract::token_nameContractMemberStateTrait;
use contract::token_symbolContractMemberStateTrait;
use contract::underlyingContractMemberStateTrait;

fn initializer(
    ref self: ContractState,
    owner: ContractAddress,
    market: ContractAddress,
    underlying: ContractAddress,
    name: felt252,
    symbol: felt252,
    decimals: felt252
) {
    assert(owner.is_non_zero(), errors::ZERO_ADDRESS);
    assert(market.is_non_zero(), errors::ZERO_ADDRESS);
    assert(underlying.is_non_zero(), errors::ZERO_ADDRESS);

    ownable::initializer(ref self, owner);

    self.market.write(market);
    self.underlying.write(underlying);

    // We probably don't need to range check `_decimals` as it's checked against the real token
    // when adding reserves anyways.
    self.token_name.write(name);
    self.token_symbol.write(symbol);
    self.token_decimals.write(decimals);
}

fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
    let amount: felt252 = amount.try_into().expect(errors::AMOUNT_OUT_OF_RANGE);
    felt_transfer(ref self, recipient, amount)
}

fn felt_transfer(ref self: ContractState, recipient: ContractAddress, amount: felt252) -> bool {
    let caller = get_caller_address();

    // NOTE: this exploit should no longer be possible since all transactions need must go through
    //       the __execute__ method now, but we're still keeping it just in case
    assert(caller.is_non_zero(), errors::ZERO_ADDRESS);

    internal::transfer_internal(
        ref self,
        caller, // from_account
        recipient, // to_account
        amount, // amount
        false, // is_amount_raw
        true // check_collateralization
    );

    true
}

fn transferFrom(
    ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
) -> bool {
    let amount: felt252 = amount.try_into().expect(errors::AMOUNT_OUT_OF_RANGE);
    felt_transfer_from(ref self, sender, recipient, amount)
}

fn felt_transfer_from(
    ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: felt252
) -> bool {
    let caller = get_caller_address();

    // NOTE: this exploit should no longer be possible since all transactions need must go through
    //       the __execute__ method now, but we're still keeping it just in case
    assert(caller.is_non_zero(), errors::ZERO_ADDRESS);

    // Allowances are scaled so we can just subtract directly
    let existing_allowance = self.allowances.read((sender, caller));
    let new_allowance = safe_math::sub(existing_allowance, amount);
    self.allowances.write((sender, caller), new_allowance);

    let new_allowance: u256 = new_allowance.into();
    self
        .emit(
            contract::Event::Approval(
                contract::Approval { owner: sender, spender: caller, value: new_allowance }
            )
        );

    internal::transfer_internal(
        ref self,
        sender, // from_account
        recipient, // to_account
        amount, // amount
        false, // is_amount_raw
        true, // check_collateralization
    );

    true
}

fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
    let amount: felt252 = amount.try_into().expect(errors::AMOUNT_OUT_OF_RANGE);
    felt_approve(ref self, spender, amount)
}

fn felt_approve(ref self: ContractState, spender: ContractAddress, amount: felt252) -> bool {
    let caller = get_caller_address();

    // NOTE: this exploit should no longer be possible since all transactions need must go through
    //       the __execute__ method now, but we're still keeping it just in case
    assert(caller.is_non_zero(), errors::ZERO_ADDRESS);

    self.allowances.write((caller, spender), amount);

    let amount: u256 = amount.into();

    self
        .emit(
            contract::Event::Approval(
                contract::Approval { owner: caller, spender: spender, value: amount }
            )
        );

    true
}

fn transfer_all(ref self: ContractState, recipient: ContractAddress) -> felt252 {
    let caller = get_caller_address();

    // NOTE: this exploit should no longer be possible since all transactions need must go through
    //       the __execute__ method now, but we're still keeping it just in case
    assert(caller.is_non_zero(), errors::ZERO_ADDRESS);

    let sender_raw_balance = self.raw_balances.read(caller);
    let transferred_amount = internal::transfer_internal(
        ref self,
        caller, // from_account
        recipient, // to_account
        sender_raw_balance, // amount
        true, // is_amount_raw
        true, // check_collateralization
    );

    transferred_amount
}

fn upgrade(ref self: ContractState, new_implementation: ClassHash) {
    ownable::assert_only_owner(@self);
    replace_class_syscall(new_implementation).unwrap_syscall();

    self
        .emit(
            contract::Event::ContractUpgraded(
                contract::ContractUpgraded { new_class_hash: new_implementation }
            )
        );
}

fn mint(ref self: ContractState, to: ContractAddress, amount: felt252) -> bool {
    internal::only_market(@self);

    assert(to.is_non_zero(), errors::MINT_TO_ZERO);
    assert(amount.is_non_zero(), errors::INVALID_MINT_AMOUNT);

    let accumulator = internal::get_accumulator(@self);

    // We're disallowing zero `amount` but allowing zero `scaled_down_amount` here, because it
    // would be difficult for callers to determine whether the amount would be zero after
    // scaling down.
    let scaled_down_amount = safe_decimal_math::div(amount, accumulator);

    let raw_balance_before = self.raw_balances.read(to);
    let raw_balance_after = safe_math::add(raw_balance_before, scaled_down_amount);
    self.raw_balances.write(to, raw_balance_after);

    let raw_supply_before = self.raw_total_supply.read();
    let raw_supply_after = safe_math::add(raw_supply_before, scaled_down_amount);
    self.raw_total_supply.write(raw_supply_after);

    let amount: u256 = amount.into();
    self
        .emit(
            contract::Event::Transfer(
                contract::Transfer { from: contract_address_const::<0>(), to, value: amount }
            )
        );

    raw_balance_before == 0
}

fn burn(ref self: ContractState, user: ContractAddress, amount: felt252) {
    internal::only_market(@self);

    let accumulator = internal::get_accumulator(@self);

    let scaled_down_amount = safe_decimal_math::div(amount, accumulator);
    assert(scaled_down_amount.is_non_zero(), errors::INVALID_BURN_AMOUNT);

    let raw_balance_before = self.raw_balances.read(user);
    let raw_balance_after = safe_math::sub(raw_balance_before, scaled_down_amount);
    self.raw_balances.write(user, raw_balance_after);

    let raw_supply_before = self.raw_total_supply.read();
    let raw_supply_after = safe_math::sub(raw_supply_before, scaled_down_amount);
    self.raw_total_supply.write(raw_supply_after);

    let amount: u256 = amount.into();
    self
        .emit(
            contract::Event::Transfer(
                contract::Transfer { from: user, to: contract_address_const::<0>(), value: amount }
            )
        );
}

fn burn_all(ref self: ContractState, user: ContractAddress) -> felt252 {
    internal::only_market(@self);

    let raw_balance = self.raw_balances.read(user);
    assert(raw_balance.is_non_zero(), errors::INVALID_BURN_AMOUNT);

    self.raw_balances.write(user, 0);

    let raw_supply_before = self.raw_total_supply.read();
    let raw_supply_after = safe_math::sub(raw_supply_before, raw_balance);
    self.raw_total_supply.write(raw_supply_after);

    let accumulator = internal::get_accumulator(@self);
    let scaled_up_amount = safe_decimal_math::mul(raw_balance, accumulator);
    let scaled_up_amount_u256: u256 = scaled_up_amount.into();
    self
        .emit(
            contract::Event::Transfer(
                contract::Transfer {
                    from: user, to: contract_address_const::<0>(), value: scaled_up_amount_u256
                }
            )
        );

    scaled_up_amount
}

fn move(
    ref self: ContractState,
    from_account: ContractAddress,
    to_account: ContractAddress,
    amount: felt252
) {
    internal::only_market(@self);

    // No need to check collateralization as `Market` only moves for liquidation
    internal::transfer_internal(
        ref self,
        from_account, // from_account
        to_account, // to_account
        amount, // amount
        false, // is_amount_raw
        false // check_collateralization
    );
}

fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
    ownable::transfer_ownership(ref self, new_owner);
}

fn renounce_ownership(ref self: ContractState) {
    ownable::renounce_ownership(ref self);
}
