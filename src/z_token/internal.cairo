use traits::Into;
use zeroable::Zeroable;

use starknet::event::EventEmitter;
use starknet::{ContractAddress, get_caller_address};

// Hack to simulate the `crate` keyword
use super::super as crate;

use crate::interfaces::{IMarketDispatcher, IMarketDispatcherTrait};
use crate::libraries::{safe_decimal_math, safe_math};

use super::errors;

use super::ZToken as contract;

use contract::ContractState;

// These are hacks that depend on compiler implementation details :(
// But they're needed for refactoring the contract code into modules like this one.
use contract::marketContractMemberStateTrait;
use contract::raw_balancesContractMemberStateTrait;
use contract::underlyingContractMemberStateTrait;

fn only_market(self: @ContractState) {
    let market_addr = self.market.read();
    let caller = get_caller_address();
    assert(market_addr == caller, errors::NOT_MARKET);
}

fn get_accumulator(self: @ContractState) -> felt252 {
    let market_addr = self.market.read();
    let underlying_addr = self.underlying.read();
    IMarketDispatcher { contract_address: market_addr }.get_lending_accumulator(underlying_addr)
}

/// Returns the amount transferred.
fn transfer_internal(
    ref self: ContractState,
    from_account: ContractAddress,
    to_account: ContractAddress,
    amount: felt252,
    is_amount_raw: bool,
    check_collateralization: bool
) -> felt252 {
    let accumulator = get_accumulator(@self);

    let (raw_amount, face_amount) = if is_amount_raw {
        let scaled_up_amount = safe_decimal_math::mul(amount, accumulator);
        (amount, scaled_up_amount)
    } else {
        let scaled_down_amount = safe_decimal_math::div(amount, accumulator);
        (scaled_down_amount, amount)
    };

    assert(raw_amount.is_non_zero(), errors::INVALID_TRANSFER_AMOUNT);

    // No need to check from balance first because SafeMath will fail
    let raw_from_balance_before = self.raw_balances.read(from_account);
    let raw_from_balance_after = safe_math::sub(raw_from_balance_before, raw_amount);
    self.raw_balances.write(from_account, raw_from_balance_after);

    let raw_to_balance_before = self.raw_balances.read(to_account);
    let raw_to_balance_after = safe_math::add(raw_to_balance_before, raw_amount);
    self.raw_balances.write(to_account, raw_to_balance_after);

    let face_amount_u256: u256 = face_amount.into();
    self
        .emit(
            contract::Event::Transfer(
                contract::Transfer { from: from_account, to: to_account, value: face_amount_u256 }
            )
        );
    self
        .emit(
            contract::Event::RawTransfer(
                contract::RawTransfer {
                    from: from_account,
                    to: to_account,
                    raw_value: raw_amount,
                    accumulator: accumulator,
                    face_value: face_amount
                }
            )
        );

    if check_collateralization {
        let market_addr = self.market.read();

        // Skips check if token is not used as collateral
        let underlying_token = self.underlying.read();
        let collateral_enabled = IMarketDispatcher { contract_address: market_addr }
            .is_collateral_enabled(from_account, // user
             underlying_token // token
            );
        if !collateral_enabled {
            return face_amount;
        }

        let is_undercollateralized = IMarketDispatcher { contract_address: market_addr }
            .is_user_undercollateralized(from_account, // user
             true // apply_borrow_factor
            );

        assert(!is_undercollateralized, errors::INVALID_COLLATERALIZATION);

        face_amount
    } else {
        face_amount
    }
}
