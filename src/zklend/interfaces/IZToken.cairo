// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IZToken {
    //
    // Getters
    //

    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func totalSupply() -> (total_supply: Uint256) {
    }

    func felt_total_supply() -> (total_supply: felt) {
    }

    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func felt_balance_of(account: felt) -> (balance: felt) {
    }

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256) {
    }

    func felt_allowance(owner: felt, spender: felt) -> (remaining: felt) {
    }

    func underlying_token() -> (token: felt) {
    }

    func get_raw_total_supply() -> (raw_supply: felt) {
    }

    //
    // Permissionless entrypoints
    //

    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func felt_transfer(recipient: felt, amount: felt) -> (success: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func felt_transfer_from(sender: felt, recipient: felt, amount: felt) -> (success: felt) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }

    func felt_approve(spender: felt, amount: felt) -> (success: felt) {
    }

    func transfer_all(recipient: felt) -> (amount_transferred: felt) {
    }

    //
    // Permissioned entrypoints
    //

    func mint(to: felt, amount: felt) -> (zero_balance_before: felt) {
    }

    func burn(user: felt, amount: felt) {
    }

    func burn_all(user: felt) -> (amount_burnt: felt) {
    }

    func move(from_account: felt, to_account: felt, amount: felt) {
    }

    func transfer_ownership(new_owner: felt) {
    }

    func renounce_ownership() {
    }
}
