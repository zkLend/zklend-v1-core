// Note to code readers
//
// The original codebase was written in Cairo 0 during the early days, and the code you're reading
// right now is almost the _direct translation_ of the orignal code into Cairo (1). The process
// worked by manually porting the code line by line. This is because the original code has already
// been deployed into production, and we need to carefully make sure it's backward-compatible.
//
// As such, there might be places where the implementation feels odd and non-idiomatic. It's most
// likely the legacy from the original code, as Cairo 0 was extremely limited (it didn't even have
// loops!). These can be fixed later by refactoring and optimizing the code, though it's quite
// unlike to happen. After all, if it ain't broken, don't fix it :)

use option::OptionTrait;
use traits::{Into, TryInto};
use zeroable::Zeroable;

use starknet::event::EventEmitter;
use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};

// Hack to simulate the `crate` keyword
use super::super as crate;

use crate::interfaces::{
    IERC20Dispatcher, IERC20DispatcherTrait, IInterestRateModelDispatcher,
    IInterestRateModelDispatcherTrait, IPriceOracleDispatcher, IPriceOracleDispatcherTrait,
    IZklendFlashCallbackDispatcher, IZklendFlashCallbackDispatcherTrait, IZTokenDispatcher,
    IZTokenDispatcherTrait, ModelRates
};
use crate::libraries::{math, safe_decimal_math, safe_math};

use super::{errors, view};

use super::storage::{ReservesStorageShortcuts, ReservesStorageShortcutsImpl, StorageBatch1};

use super::Market as contract;

use contract::ContractState;

// These are hacks that depend on compiler implementation details :(
// But they're needed for refactoring the contract code into modules like this one.
use contract::oracleContractStateTrait;
use contract::raw_user_debtsContractStateTrait;
use contract::reserve_countContractStateTrait;
use contract::reserve_indicesContractStateTrait;
use contract::reserve_tokensContractStateTrait;
use contract::reservesContractStateTrait;
use contract::treasuryContractStateTrait;
use contract::user_flagsContractStateTrait;

const DEBT_FLAG_FILTER: u256 = 0x2aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

struct UserCollateralData {
    collateral_value: felt252,
    collateral_required: felt252
}

struct DebtRepaid {
    raw_amount: felt252,
    face_amount: felt252
}

struct UpdatedAccumulators {
    lending_accumulator: felt252,
    debt_accumulator: felt252
}

fn deposit(ref self: ContractState, token: ContractAddress, amount: felt252) {
    assert(amount.is_non_zero(), errors::ZERO_AMOUNT);

    let caller = get_caller_address();
    let this_address = get_contract_address();

    let UpdatedAccumulators{debt_accumulator: updated_debt_accumulator, .. } = update_accumulators(
        ref self, token
    );

    assert_reserve_enabled(@self, token);
    let z_token_address = self.reserves.read_z_token_address(token);

    // Updates interest rate
    update_rates_and_raw_total_debt(
        ref self,
        token, // token
        updated_debt_accumulator, // updated_debt_accumulator
        false, // is_delta_reserve_balance_negative
        amount, // abs_delta_reserve_balance
        false, // is_delta_raw_total_debt_negative
        0 // abs_delta_raw_total_debt
    );

    self
        .emit(
            contract::Event::Deposit(
                contract::Deposit { user: caller, token: token, face_amount: amount }
            )
        );

    // Takes token from user

    let amount_u256: u256 = amount.into();
    let transfer_success = IERC20Dispatcher {
        contract_address: token, 
    }.transferFrom(caller, this_address, amount_u256);
    assert(transfer_success, errors::TRANSFERFROM_FAILED);

    // Mints ZToken to user
    IZTokenDispatcher { contract_address: z_token_address }.mint(caller, amount);
}

fn withdraw(ref self: ContractState, token: ContractAddress, amount: felt252) {
    assert(amount.is_non_zero(), errors::ZERO_AMOUNT);

    let caller = get_caller_address();
    withdraw_internal(ref self, caller, token, amount);
}

fn withdraw_all(ref self: ContractState, token: ContractAddress) {
    let caller = get_caller_address();
    withdraw_internal(ref self, caller, token, 0);
}

fn borrow(ref self: ContractState, token: ContractAddress, amount: felt252) {
    let caller = get_caller_address();

    let UpdatedAccumulators{debt_accumulator: updated_debt_accumulator, .. } = update_accumulators(
        ref self, token
    );

    assert_reserve_enabled(@self, token);

    let scaled_down_amount = safe_decimal_math::div(amount, updated_debt_accumulator);
    assert(scaled_down_amount.is_non_zero(), errors::INVALID_AMOUNT);

    // Updates user debt data
    let raw_user_debt_before = self.raw_user_debts.read((caller, token));
    let raw_user_debt_after = safe_math::add(raw_user_debt_before, scaled_down_amount);
    self.raw_user_debts.write((caller, token), raw_user_debt_after);

    set_user_has_debt(ref self, caller, token, raw_user_debt_before, raw_user_debt_after);

    // Updates interest rate
    update_rates_and_raw_total_debt(
        ref self,
        token, // token
        updated_debt_accumulator, // updated_debt_accumulator
        true, // is_delta_reserve_balance_negative
        amount, // abs_delta_reserve_balance
        false, // is_delta_raw_total_debt_negative
        scaled_down_amount // abs_delta_raw_total_debt
    );

    // Enforces token debt limit
    assert_debt_limit_satisfied(@self, token);

    self
        .emit(
            contract::Event::Borrowing(
                contract::Borrowing {
                    user: caller, token: token, raw_amount: scaled_down_amount, face_amount: amount
                }
            )
        );

    // It's easier to post-check collateralization factor
    assert_not_undercollateralized(@self, caller, true);

    let amount_u256: u256 = amount.into();
    let transfer_success = IERC20Dispatcher {
        contract_address: token
    }.transfer(caller, amount_u256);
    assert(transfer_success, errors::TRANSFER_FAILED);
}

fn repay(ref self: ContractState, token: ContractAddress, amount: felt252) {
    assert(amount.is_non_zero(), errors::ZERO_AMOUNT);

    let caller = get_caller_address();

    let DebtRepaid{raw_amount, face_amount } = repay_debt_route_internal(
        ref self, caller, caller, token, amount
    );
    self
        .emit(
            contract::Event::Repayment(
                contract::Repayment {
                    repayer: caller, beneficiary: caller, token, raw_amount, face_amount
                }
            )
        );
}

fn repay_for(
    ref self: ContractState, token: ContractAddress, amount: felt252, beneficiary: ContractAddress
) {
    assert(amount.is_non_zero(), errors::ZERO_AMOUNT);

    assert(beneficiary.is_non_zero(), errors::ZERO_ADDRESS);

    let caller = get_caller_address();

    let DebtRepaid{raw_amount, face_amount } = repay_debt_route_internal(
        ref self, caller, beneficiary, token, amount
    );
    self
        .emit(
            contract::Event::Repayment(
                contract::Repayment { repayer: caller, beneficiary, token, raw_amount, face_amount }
            )
        );
}

fn repay_all(ref self: ContractState, token: ContractAddress) {
    let caller = get_caller_address();

    let DebtRepaid{raw_amount, face_amount } = repay_debt_route_internal(
        ref self, caller, caller, token, 0
    );
    self
        .emit(
            contract::Event::Repayment(
                contract::Repayment {
                    repayer: caller, beneficiary: caller, token, raw_amount, face_amount
                }
            )
        );
}

fn enable_collateral(ref self: ContractState, token: ContractAddress) {
    let caller = get_caller_address();

    assert_reserve_exists(@self, token);

    set_collateral_usage(ref self, caller, token, true);

    self
        .emit(
            contract::Event::CollateralEnabled(contract::CollateralEnabled { user: caller, token })
        );
}

fn disable_collateral(ref self: ContractState, token: ContractAddress) {
    let caller = get_caller_address();

    assert_reserve_exists(@self, token);

    set_collateral_usage(ref self, caller, token, false);

    // It's easier to post-check collateralization factor
    assert_not_undercollateralized(@self, caller, true);

    self
        .emit(
            contract::Event::CollateralDisabled(
                contract::CollateralDisabled { user: caller, token }
            )
        );
}

fn liquidate(
    ref self: ContractState,
    user: ContractAddress,
    debt_token: ContractAddress,
    amount: felt252,
    collateral_token: ContractAddress
) {
    let caller = get_caller_address();

    // Validates input
    assert(amount.is_non_zero(), errors::ZERO_AMOUNT);

    assert_reserve_enabled(@self, debt_token);
    assert_reserve_enabled(@self, collateral_token);
    let debt_reserve_decimals = self.reserves.read_decimals(debt_token);
    let collateral_reserve = self.reserves.read(collateral_token);

    // Liquidator repays debt for user
    let DebtRepaid{raw_amount, .. } = repay_debt_route_internal(
        ref self, caller, user, debt_token, amount
    );

    // Can only take from assets being used as collateral
    let is_collateral = is_used_as_collateral(@self, user, collateral_token);
    assert(is_collateral, errors::NONCOLLATERAL_TOKEN);

    // Liquidator withdraws collateral from user
    let oracle_addr = self.oracle.read();
    let debt_token_price = IPriceOracleDispatcher {
        contract_address: oracle_addr
    }.get_price(debt_token);
    let collateral_token_price = IPriceOracleDispatcher {
        contract_address: oracle_addr
    }.get_price(collateral_token);
    let debt_value_repaid = safe_decimal_math::mul_decimals(
        debt_token_price, amount, debt_reserve_decimals
    );
    let equivalent_collateral_amount = safe_decimal_math::div_decimals(
        debt_value_repaid, collateral_token_price, collateral_reserve.decimals
    );
    let one_plus_liquidation_bonus = safe_math::add(
        safe_decimal_math::SCALE, collateral_reserve.liquidation_bonus
    );
    let collateral_amount_after_bonus = safe_decimal_math::mul(
        equivalent_collateral_amount, one_plus_liquidation_bonus
    );

    IZTokenDispatcher {
        contract_address: collateral_reserve.z_token_address
    }.move(user, caller, collateral_amount_after_bonus);

    // Checks user collateralization factor after liquidation
    assert_not_overcollateralized(@self, user, false);

    self
        .emit(
            contract::Event::Liquidation(
                contract::Liquidation {
                    liquidator: caller,
                    user,
                    debt_token,
                    debt_raw_amount: raw_amount,
                    debt_face_amount: amount,
                    collateral_token,
                    collateral_amount: collateral_amount_after_bonus,
                }
            )
        );
}

fn flash_loan(
    ref self: ContractState,
    receiver: ContractAddress,
    token: ContractAddress,
    amount: felt252,
    calldata: Span::<felt252>
) {
    let this_address = get_contract_address();

    // Validates input
    assert(amount.is_non_zero(), errors::ZERO_AMOUNT);

    assert_reserve_enabled(@self, token);
    let flash_loan_fee = self.reserves.read_flash_loan_fee(token);

    // Calculates minimum balance after the callback
    let loan_fee = safe_decimal_math::mul(amount, flash_loan_fee);
    let reserve_balance_before: felt252 = IERC20Dispatcher {
        contract_address: token
    }.balanceOf(this_address).try_into().expect(errors::BALANCE_OVERFLOW);
    let min_balance = safe_math::add(reserve_balance_before, loan_fee);

    // Sends funds to receiver
    let amount_u256: u256 = amount.into();
    let transfer_success = IERC20Dispatcher {
        contract_address: token
    }.transfer(receiver, amount_u256);
    assert(transfer_success, errors::TRANSFER_FAILED);

    let caller = get_caller_address();

    // Calls receiver callback (which should return funds to this contract)
    IZklendFlashCallbackDispatcher {
        contract_address: receiver
    }.zklend_flash_callback(caller, calldata);

    // Checks if enough funds have been returned
    let reserve_balance_after: felt252 = IERC20Dispatcher {
        contract_address: token
    }.balanceOf(this_address).try_into().expect(errors::BALANCE_OVERFLOW);
    assert(
        Into::<_, u256>::into(min_balance) <= Into::<_, u256>::into(reserve_balance_after),
        errors::INSUFFICIENT_AMOUNT_REPAID
    );

    // Updates accumulators (for interest accumulation only)
    let UpdatedAccumulators{debt_accumulator: updated_debt_accumulator, .. } = update_accumulators(
        ref self, token
    );

    // Distributes excessive funds (flash loan fees)
    // `updated_debt_accumulator` from above is still valid as this function does not touch debt
    settle_extra_reserve_balance(ref self, token);

    // Updates rates
    update_rates_and_raw_total_debt(
        ref self,
        token, // token
        updated_debt_accumulator, // updated_debt_accumulator
        false, // is_delta_reserve_balance_negative
        0, // abs_delta_reserve_balance
        false, // is_delta_raw_total_debt_negative
        0, // abs_delta_raw_total_debt
    );

    let actual_fee = safe_math::sub(reserve_balance_after, reserve_balance_before);
    self
        .emit(
            contract::Event::FlashLoan(
                contract::FlashLoan { initiator: caller, receiver, token, amount, fee: actual_fee }
            )
        );
}

/// ASSUMPTION: `token` maps to a valid reserve.
fn set_collateral_usage(
    ref self: ContractState, user: ContractAddress, token: ContractAddress, used: bool
) {
    let reserve_index = self.reserve_indices.read(token);
    set_user_flag(ref self, user, reserve_index * 2, used);
}

/// ASSUMPTION: `token` maps to a valid reserve.
fn set_user_has_debt(
    ref self: ContractState,
    user: ContractAddress,
    token: ContractAddress,
    debt_before: felt252,
    debt_after: felt252
) {
    let reserve_index = self.reserve_indices.read(token);
    if debt_before == 0 && debt_after != 0 {
        set_user_flag(ref self, user, reserve_index * 2 + 1, true);
    } else if debt_before != 0 && debt_after == 0 {
        set_user_flag(ref self, user, reserve_index * 2 + 1, false);
    }
}

fn set_user_flag(ref self: ContractState, user: ContractAddress, offset: felt252, set: bool) {
    let reserve_slot: u256 = math::shl(1, offset).into();
    let existing_map: u256 = self.user_flags.read(user).into();

    let new_map: u256 = if set {
        BitOr::bitor(existing_map, reserve_slot)
    } else {
        let inverse_slot = BitNot::bitnot(reserve_slot);
        BitAnd::bitand(existing_map, inverse_slot)
    };

    // The max value produced by `math::shl` is `2 ^ 251 - 1`. Since user map values can only be
    // produced from bitwise-or results of `math::shl` outputs, they would never be larger than
    // `2 ^ 251 - 1`, ensuring that it's always a valid `felt252`. So it's safe to unwrap here.
    let new_map: felt252 = new_map.try_into().unwrap();

    self.user_flags.write(user, new_map);
}

/// Panicks if `token` does not map to a valid reserve.
///
/// ASSUMPTION: `token` maps to a valid reserve
fn is_used_as_collateral(
    self: @ContractState, user: ContractAddress, token: ContractAddress
) -> bool {
    let reserve_index = self.reserve_indices.read(token);
    let reserve_slot: u256 = math::shl(1, reserve_index * 2).into();
    let existing_map: u256 = self.user_flags.read(user).into();

    let and_result = BitAnd::bitand(existing_map, reserve_slot);
    let is_used = and_result != 0;

    is_used
}

fn user_has_debt(self: @ContractState, user: ContractAddress) -> bool {
    let map: u256 = self.user_flags.read(user).into();

    let and_result = BitAnd::bitand(map, DEBT_FLAG_FILTER);
    let has_debt = and_result != 0;

    has_debt
}

#[inline(always)]
fn assert_not_overcollateralized(
    self: @ContractState, user: ContractAddress, apply_borrow_factor: bool
) {
    let user_overcollateralized = is_overcollateralized(self, user, apply_borrow_factor);
    assert(!user_overcollateralized, errors::INVALID_LIQUIDATION);
}

#[inline(always)]
fn assert_not_undercollateralized(
    self: @ContractState, user: ContractAddress, apply_borrow_factor: bool
) {
    let user_not_undercollateralized = is_not_undercollateralized(self, user, apply_borrow_factor);
    assert(user_not_undercollateralized, errors::INSUFFICIENT_COLLATERAL);
}

fn is_not_undercollateralized(
    self: @ContractState, user: ContractAddress, apply_borrow_factor: bool
) -> bool {
    // Skips expensive collateralization check if user has no debt at all
    let has_debt = user_has_debt(self, user);
    if !has_debt {
        return true;
    }

    let UserCollateralData{collateral_value, collateral_required } = calculate_user_collateral_data(
        self, user, apply_borrow_factor
    );
    Into::<_, u256>::into(collateral_required) <= Into::<_, u256>::into(collateral_value)
}

/// Same as `is_not_undercollateralized` but returns `false` if equal. Only used in
/// liquidations.
fn is_overcollateralized(
    self: @ContractState, user: ContractAddress, apply_borrow_factor: bool
) -> bool {
    // Not using the skip-if-no-debt optimization here because in liquidations the user always
    // has debt left. Checking for debt flags is thus wasteful.

    let UserCollateralData{collateral_value, collateral_required } = calculate_user_collateral_data(
        self, user, apply_borrow_factor
    );
    Into::<_, u256>::into(collateral_required) < Into::<_, u256>::into(collateral_value)
}

// TODO: refactor the recursion away since Cairo supports loops now (see notes at the top)
fn calculate_user_collateral_data(
    self: @ContractState, user: ContractAddress, apply_borrow_factor: bool
) -> UserCollateralData {
    let reserve_cnt = self.reserve_count.read();
    if reserve_cnt.is_zero() {
        UserCollateralData { collateral_value: 0, collateral_required: 0 }
    } else {
        let flags: u256 = self.user_flags.read(user).into();

        let UserCollateralData{collateral_value, collateral_required } =
            calculate_user_collateral_data_loop(
            self, user, apply_borrow_factor, flags, reserve_cnt, 0
        );

        UserCollateralData { collateral_value, collateral_required }
    }
}

// TODO: refactor this away since Cairo supports loops now (see notes at the top)
/// ASSUMPTION: `reserve_count` is not zero.
fn calculate_user_collateral_data_loop(
    self: @ContractState,
    user: ContractAddress,
    apply_borrow_factor: bool,
    flags: u256,
    reserve_count: felt252,
    reserve_index: felt252
) -> UserCollateralData {
    if reserve_index == reserve_count {
        return UserCollateralData { collateral_value: 0, collateral_required: 0 };
    }

    let UserCollateralData{collateral_value: collateral_value_of_rest,
    collateral_required: collateral_required_of_rest } =
        calculate_user_collateral_data_loop(
        self, user, apply_borrow_factor, flags, reserve_count, reserve_index + 1
    );

    let reserve_slot: u256 = math::shl(1, reserve_index * 2).into();
    let reserve_slot_and = BitAnd::bitand(flags, reserve_slot);

    let reserve_token = self.reserve_tokens.read(reserve_index);

    let current_collateral_required = get_collateral_usd_value_required_for_token(
        self, user, reserve_token, apply_borrow_factor
    );
    let total_collateral_required = safe_math::add(
        current_collateral_required, collateral_required_of_rest
    );

    if reserve_slot_and.is_zero() {
        // Reserve not used as collateral
        UserCollateralData {
            collateral_value: collateral_value_of_rest,
            collateral_required: total_collateral_required
        }
    } else {
        let discounted_collateral_value = get_user_collateral_usd_value_for_token(
            self, user, reserve_token
        );
        let total_collateral_value = safe_math::add(
            discounted_collateral_value, collateral_value_of_rest
        );

        UserCollateralData {
            collateral_value: total_collateral_value, collateral_required: total_collateral_required
        }
    }
}

/// ASSUMPTION: `token` is a valid reserve.
#[inline(always)]
fn get_collateral_usd_value_required_for_token(
    self: @ContractState, user: ContractAddress, token: ContractAddress, apply_borrow_factor: bool
) -> felt252 {
    let debt_value = get_user_debt_usd_value_for_token(self, user, token);
    if apply_borrow_factor {
        let borrow_factor = self.reserves.read_borrow_factor(token);
        let collateral_required = safe_decimal_math::div(debt_value, borrow_factor);
        collateral_required
    } else {
        debt_value
    }
}

/// ASSUMPTION: `token` is a valid reserve.
#[inline(always)]
fn get_user_debt_usd_value_for_token(
    self: @ContractState, user: ContractAddress, token: ContractAddress
) -> felt252 {
    let raw_debt_balance = self.raw_user_debts.read((user, token));
    if raw_debt_balance.is_zero() {
        return 0;
    }

    let debt_accumulator = view::get_debt_accumulator(self, token);
    let scaled_up_debt_balance = safe_decimal_math::mul(raw_debt_balance, debt_accumulator);

    // Fetches price from oracle
    let oracle_addr = self.oracle.read();
    let debt_price = IPriceOracleDispatcher { contract_address: oracle_addr }.get_price(token);

    let decimals = self.reserves.read_decimals(token);

    let debt_value = safe_decimal_math::mul_decimals(debt_price, scaled_up_debt_balance, decimals);

    debt_value
}

/// ASSUMPTION: `token` is a valid reserve.
/// ASSUMPTION: `token` is used by `user` as collateral.
#[inline(always)]
fn get_user_collateral_usd_value_for_token(
    self: @ContractState, user: ContractAddress, token: ContractAddress
) -> felt252 {
    let reserve = self.reserves.read_for_get_user_collateral_usd_value_for_token(token);

    // This value already reflects interests accured since last update
    let collateral_balance = IZTokenDispatcher {
        contract_address: reserve.z_token_address
    }.felt_balance_of(user);

    // Fetches price from oracle
    let oracle_addr = self.oracle.read();
    let collateral_price = IPriceOracleDispatcher {
        contract_address: oracle_addr
    }.get_price(token);

    // `collateral_value` is represented in 8-decimal USD value
    let collateral_value = safe_decimal_math::mul_decimals(
        collateral_price, collateral_balance, reserve.decimals
    );

    // Discounts value by collateral factor
    let discounted_collateral_value = safe_decimal_math::mul(
        collateral_value, reserve.collateral_factor
    );

    discounted_collateral_value
}

/// `amount` with `0` means withdrawing all.
fn withdraw_internal(
    ref self: ContractState, user: ContractAddress, token: ContractAddress, amount: felt252
) {
    let UpdatedAccumulators{debt_accumulator: updated_debt_accumulator, .. } = update_accumulators(
        ref self, token
    );

    assert_reserve_enabled(@self, token);
    let z_token_address = self.reserves.read_z_token_address(token);

    // NOTE: it's fine to call out to external contract here before state update since it's trusted
    let amount_burnt = burn_z_token_internal(ref self, z_token_address, user, amount);

    // Updates interest rate
    update_rates_and_raw_total_debt(
        ref self,
        token, // token
        updated_debt_accumulator, // updated_debt_accumulator
        true, // is_delta_reserve_balance_negative
        amount_burnt, // abs_delta_reserve_balance
        false, // is_delta_raw_total_debt_negative
        0, // abs_delta_raw_total_debt
    );

    self
        .emit(
            contract::Event::Withdrawal(
                contract::Withdrawal { user, token, face_amount: amount_burnt }
            )
        );

    // Gives underlying tokens to user
    let amount_burnt: u256 = amount_burnt.into();
    let transfer_success = IERC20Dispatcher {
        contract_address: token
    }.transfer(user, amount_burnt);
    assert(transfer_success, errors::TRANSFER_FAILED);

    // It's easier to post-check collateralization factor, at the cost of making failed
    // transactions more expensive.
    let is_asset_used_as_collateral = is_used_as_collateral(@self, user, token);

    // No need to check if the asset is not used as collateral at all
    if is_asset_used_as_collateral {
        assert_not_undercollateralized(@self, user, true);
    }
}

/// `amount` with `0` means repaying all. Returns actual debt amounts repaid.
fn repay_debt_route_internal(
    ref self: ContractState,
    repayer: ContractAddress,
    beneficiary: ContractAddress,
    token: ContractAddress,
    amount: felt252
) -> DebtRepaid {
    assert_reserve_enabled(@self, token);

    let updated_debt_accumulator = view::get_debt_accumulator(@self, token);

    if amount.is_zero() {
        let user_raw_debt = self.raw_user_debts.read((beneficiary, token));
        assert(user_raw_debt.is_non_zero(), errors::NO_DEBT_TO_REPAY);

        let repay_amount = safe_decimal_math::mul(user_raw_debt, updated_debt_accumulator);

        repay_debt_internal(ref self, repayer, beneficiary, token, repay_amount, user_raw_debt);

        DebtRepaid { raw_amount: user_raw_debt, face_amount: repay_amount }
    } else {
        let raw_amount = safe_decimal_math::div(amount, updated_debt_accumulator);
        assert(raw_amount.is_non_zero(), errors::INVALID_AMOUNT);
        repay_debt_internal(ref self, repayer, beneficiary, token, amount, raw_amount);

        DebtRepaid { raw_amount, face_amount: amount }
    }
}

/// ASSUMPTION: `repay_amount` = `raw_amount` * Debt Accumulator.
/// ASSUMPTION: it's always called by `repay_debt_route_internal`.
/// ASSUMPTION: raw_amount is non zero.
fn repay_debt_internal(
    ref self: ContractState,
    repayer: ContractAddress,
    beneficiary: ContractAddress,
    token: ContractAddress,
    repay_amount: felt252,
    raw_amount: felt252
) {
    let this_address = get_contract_address();

    let UpdatedAccumulators{debt_accumulator: updated_debt_accumulator, .. } = update_accumulators(
        ref self, token
    );

    // No need to check if user is overpaying, as `safe_math::sub` below will fail anyways
    // No need to check collateral value. Always allow repaying even if it's undercollateralized

    // Updates user debt data
    let raw_user_debt_before = self.raw_user_debts.read((beneficiary, token));
    let raw_user_debt_after = safe_math::sub(raw_user_debt_before, raw_amount);
    self.raw_user_debts.write((beneficiary, token), raw_user_debt_after);

    set_user_has_debt(ref self, beneficiary, token, raw_user_debt_before, raw_user_debt_after);

    // Updates interest rate
    update_rates_and_raw_total_debt(
        ref self,
        token, // token
        updated_debt_accumulator, // updated_debt_accumulator
        false, // is_delta_reserve_balance_negative
        repay_amount, // abs_delta_reserve_balance
        true, // is_delta_raw_total_debt_negative
        raw_amount // abs_delta_raw_total_debt
    );

    // Takes token from user
    let repay_amount: u256 = repay_amount.into();
    let transfer_success = IERC20Dispatcher {
        contract_address: token
    }.transferFrom(repayer, this_address, repay_amount);
    assert(transfer_success, errors::TRANSFER_FAILED);
}

/// `amount` with `0` means burning all. Returns amount burnt.
fn burn_z_token_internal(
    ref self: ContractState, z_token: ContractAddress, user: ContractAddress, amount: felt252
) -> felt252 {
    if amount.is_zero() {
        let amount_burnt = IZTokenDispatcher { contract_address: z_token }.burn_all(user);
        amount_burnt
    } else {
        IZTokenDispatcher { contract_address: z_token }.burn(user, amount);
        amount
    }
}

fn update_accumulators(ref self: ContractState, token: ContractAddress) -> UpdatedAccumulators {
    let block_timestamp: felt252 = get_block_timestamp().into();

    let updated_lending_accumulator = view::get_lending_accumulator(@self, token);
    let updated_debt_accumulator = view::get_debt_accumulator(@self, token);

    self
        .emit(
            contract::Event::AccumulatorsSync(
                contract::AccumulatorsSync {
                    token,
                    lending_accumulator: updated_lending_accumulator,
                    debt_accumulator: updated_debt_accumulator
                }
            )
        );

    // It's okay to call this function here as the updated accumulators haven't been written into
    // storage yet
    let amount_to_treasury = view::get_pending_treasury_amount(@self, token);

    // No need to check reserve existence since it's done in `get_lending_accumulator` and
    // `get_debt_accumulator`
    let z_token_address = self.reserves.read_z_token_address(token);

    self
        .reserves
        .write_accumulators(
            token, block_timestamp, updated_lending_accumulator, updated_debt_accumulator
        );

    // No need to check whether treasury address is zero as amount would be zero anyways
    if amount_to_treasury.is_non_zero() {
        let treasury_addr = self.treasury.read();
        IZTokenDispatcher {
            contract_address: z_token_address
        }.mint(treasury_addr, amount_to_treasury);
    }

    UpdatedAccumulators {
        lending_accumulator: updated_lending_accumulator, debt_accumulator: updated_debt_accumulator
    }
}

fn update_rates_and_raw_total_debt(
    ref self: ContractState,
    token: ContractAddress,
    updated_debt_accumulator: felt252,
    is_delta_reserve_balance_negative: bool,
    abs_delta_reserve_balance: felt252,
    is_delta_raw_total_debt_negative: bool,
    abs_delta_raw_total_debt: felt252,
) {
    let this_address = get_contract_address();

    let StorageBatch1{interest_rate_model, raw_total_debt: raw_total_debt_before } = self
        .reserves
        .read_interest_rate_model_and_raw_total_debt(token);

    // Makes sure reserve exists
    // (the caller must check it's enabled if needed since it's not validated here)
    assert(interest_rate_model.is_non_zero(), errors::RESERVE_NOT_FOUND);

    let reserve_balance_before: felt252 = IERC20Dispatcher {
        contract_address: token
    }.balanceOf(this_address).try_into().expect(errors::BALANCE_OVERFLOW);

    let reserve_balance_after = if is_delta_reserve_balance_negative {
        safe_math::sub(reserve_balance_before, abs_delta_reserve_balance)
    } else {
        safe_math::add(reserve_balance_before, abs_delta_reserve_balance)
    };

    let raw_total_debt_after = if is_delta_raw_total_debt_negative {
        safe_math::sub(raw_total_debt_before, abs_delta_raw_total_debt)
    } else {
        safe_math::add(raw_total_debt_before, abs_delta_raw_total_debt)
    };

    let scaled_up_total_debt_after = safe_decimal_math::mul(
        raw_total_debt_after, updated_debt_accumulator
    );
    let ModelRates{lending_rate: new_lending_rate, borrowing_rate: new_borrowing_rate } =
        IInterestRateModelDispatcher {
        contract_address: interest_rate_model
    }.get_interest_rates(reserve_balance_after, scaled_up_total_debt_after);

    // Writes to storage
    self.reserves.write_rates(token, new_lending_rate, new_borrowing_rate);
    if raw_total_debt_before != raw_total_debt_after {
        self.reserves.write_raw_total_debt(token, raw_total_debt_after);
    }

    self
        .emit(
            contract::Event::InterestRatesSync(
                contract::InterestRatesSync {
                    token, lending_rate: new_lending_rate, borrowing_rate: new_borrowing_rate
                }
            )
        );
}

/// Checks reserve exists.
fn assert_reserve_exists(self: @ContractState, token: ContractAddress) {
    let z_token = self.reserves.read_z_token_address(token);
    assert(z_token.is_non_zero(), errors::RESERVE_NOT_FOUND);
}

/// Checks reserve is enabled.
fn assert_reserve_enabled(self: @ContractState, token: ContractAddress) {
    let enabled = self.reserves.read_enabled(token);
    assert(enabled, errors::RESERVE_NOT_ENABLED);
}

/// Checks if the debt limit is satisfied.
fn assert_debt_limit_satisfied(self: @ContractState, token: ContractAddress) {
    let debt_limit = self.reserves.read_debt_limit(token);

    // 0 means no limit
    if debt_limit.is_non_zero() {
        let raw_total_debt = self.reserves.read_raw_total_debt(token);

        let debt_accumulator = view::get_debt_accumulator(self, token);
        let scaled_debt = safe_decimal_math::mul(raw_total_debt, debt_accumulator);

        assert(
            Into::<_, u256>::into(scaled_debt) <= Into::<_, u256>::into(debt_limit),
            errors::DEBT_LIMIT_EXCEEDED
        );
    }
}

/// This function is called to distribute excessive reserve assets to depositors. Such extra balance
/// can come from a variety of sources, including direct transfer of tokens into
/// this contract. However, in practice, this function is only called right after a flash loan,
/// meaning that these excessive balance would accumulate over time, but only gets settled when
/// flash loans happen.
///
/// This is a deliberate design decision:
///
/// - doing so avoids expensive settlements for small rounding errors that make little to no
///   difference to users; and
/// - it's deemed unlikely that anyone would send unsolicited funds to this contract on purpose.
///
/// An alternative implementation would be to always derive the lending accumulator from real
/// balances, and thus unifying accumulator updates. However, that would make ZToken transfers
/// unnecessarily expensive, with little benefits (same reasoning as above).
///
/// ASSUMPTION: accumulators are otherwise up to date; this function MUST only be called right after
///             `update_accumulators()`.
fn settle_extra_reserve_balance(ref self: ContractState, token: ContractAddress) {
    let this_address = get_contract_address();

    // No need to check reserve existence: deduced from assumption.
    let reserve = self.reserves.read_for_settle_extra_reserve_balance(token);

    // Accumulators are already update to date from assumption
    let scaled_up_total_debt = safe_decimal_math::mul(
        reserve.raw_total_debt, reserve.debt_accumulator
    );

    // What we _actually_ have sitting in the contract
    let reserve_balance: felt252 = IERC20Dispatcher {
        contract_address: token
    }.balanceOf(this_address).try_into().expect(errors::BALANCE_OVERFLOW);

    // The full amount if all debts are repaid
    let implicit_total_balance = safe_math::add(reserve_balance, scaled_up_total_debt);

    // What all users are _entitled_ to right now (again, accumulators are up to date)
    let raw_z_supply = IZTokenDispatcher {
        contract_address: reserve.z_token_address
    }.get_raw_total_supply();
    let owned_balance = safe_decimal_math::mul(raw_z_supply, reserve.lending_accumulator);

    let no_need_to_adjust = Into::<_,
    u256>::into(implicit_total_balance) <= Into::<_, u256>::into(owned_balance);
    if !no_need_to_adjust {
        // `implicit_total_balance > owned_balance` holds inside this branch
        let excessive_balance = safe_math::sub(implicit_total_balance, owned_balance);

        let treasury_addr = self.treasury.read();
        let effective_reserve_factor = if treasury_addr.is_zero() {
            0
        } else {
            reserve.reserve_factor
        };

        let amount_to_treasury = safe_decimal_math::mul(
            excessive_balance, effective_reserve_factor
        );
        let amount_to_depositors = safe_math::sub(excessive_balance, amount_to_treasury);

        let new_depositor_balance = safe_math::add(owned_balance, amount_to_depositors);
        let new_accumulator = safe_decimal_math::div(new_depositor_balance, raw_z_supply);

        self
            .emit(
                contract::Event::AccumulatorsSync(
                    contract::AccumulatorsSync {
                        token,
                        lending_accumulator: new_accumulator,
                        debt_accumulator: reserve.debt_accumulator
                    }
                )
            );
        self.reserves.write_lending_accumulator(token, new_accumulator);

        // Mints fee to treasury
        if amount_to_treasury.is_non_zero() {
            IZTokenDispatcher {
                contract_address: reserve.z_token_address
            }.mint(treasury_addr, amount_to_treasury);
        }
    }
}
