// SPDX-License-Identifier: MIT

%lang starknet

from zklend.internals.Market.structs import Structs

@contract_interface
namespace IMarket {
    //
    // Getters
    //

    func get_reserve_data(token: felt) -> (data: Structs.ReserveData) {
    }

    func get_lending_accumulator(token: felt) -> (res: felt) {
    }

    func get_debt_accumulator(token: felt) -> (res: felt) {
    }

    func get_pending_treasury_amount(token: felt) -> (res: felt) {
    }

    func get_total_debt_for_token(token: felt) -> (debt: felt) {
    }

    func get_user_debt_for_token(user: felt, token: felt) -> (debt: felt) {
    }

    func get_user_flags(user: felt) -> (map: felt) {
    }

    func is_user_undercollateralized(user: felt, apply_borrow_factor: felt) -> (
        is_undercollateralized: felt
    ) {
    }

    func is_collateral_enabled(user: felt, token: felt) -> (enabled: felt) {
    }

    func user_has_debt(user: felt) -> (has_debt: felt) {
    }

    //
    // Permissionless entrypoints
    //

    func deposit(token: felt, amount: felt) {
    }

    func withdraw(token: felt, amount: felt) {
    }

    func withdraw_all(token: felt) {
    }

    func borrow(token: felt, amount: felt) {
    }

    func repay(token: felt, amount: felt) {
    }

    func repay_for(token: felt, amount: felt, beneficiary: felt) {
    }

    func repay_all(token: felt) {
    }

    func enable_collateral(token: felt) {
    }

    func disable_collateral(token: felt) {
    }

    func liquidate(user: felt, debt_token: felt, amount: felt, collateral_token: felt) {
    }

    func flash_loan(
        receiver: felt, token: felt, amount: felt, calldata_len: felt, calldata: felt*
    ) {
    }

    //
    // Permissioned entrypoints
    //

    func add_reserve(
        token: felt,
        z_token: felt,
        interest_rate_model: felt,
        collateral_factor: felt,
        borrow_factor: felt,
        reserve_factor: felt,
        flash_loan_fee: felt,
        liquidation_bonus: felt,
    ) {
    }

    func set_treasury(new_treasury: felt) {
    }

    func set_debt_limit(token: felt, limit: felt) {
    }

    func transfer_ownership(new_owner: felt) {
    }

    func renounce_ownership() {
    }
}
