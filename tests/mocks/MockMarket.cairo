// SPDX-License-Identifier: BUSL-1.1

// MockMarket : IMarket

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from zklend.interfaces.IZToken import IZToken

//
// Storage
//

@storage_var
func lending_accumulator(token: felt) -> (res: felt) {
}

@storage_var
func debt_accumulator(token: felt) -> (res: felt) {
}

@storage_var
func collateral_enabled(user: felt, token: felt) -> (res: felt) {
}

@storage_var
func user_undercollateralized(user: felt) -> (res: felt) {
}

@storage_var
func last_call_result() -> (res: felt) {
}

//
// Getters
//

@view
func get_lending_accumulator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt
) -> (res: felt) {
    let (res) = lending_accumulator.read(token);
    return (res=res);
}

@view
func get_debt_accumulator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt
) -> (res: felt) {
    let (res) = debt_accumulator.read(token);
    return (res=res);
}

@view
func is_user_undercollateralized{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt
) -> (is_undercollateralized: felt) {
    let (res) = user_undercollateralized.read(user);
    return (is_undercollateralized=res);
}

@view
func is_collateral_enabled{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt, token: felt
) -> (enabled: felt) {
    let (res) = collateral_enabled.read(user, token);
    return (enabled=res);
}

@view
func get_last_call_result{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    res: felt
) {
    let (res) = last_call_result.read();
    return (res=res);
}

//
// External
//

@external
func set_lending_accumulator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt, value: felt
) {
    lending_accumulator.write(token, value);
    return ();
}

@external
func set_debt_accumulator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt, value: felt
) {
    debt_accumulator.write(token, value);
    return ();
}

@external
func set_user_undercollateralized{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt, value: felt
) {
    user_undercollateralized.write(user, value);
    return ();
}

@external
func mint_z_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    z_token: felt, to: felt, amount: felt
) {
    IZToken.mint(contract_address=z_token, to=to, amount=amount);
    return ();
}

@external
func burn_all_z_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    z_token: felt, user: felt
) {
    let (amount_burnt) = IZToken.burn_all(contract_address=z_token, user=user);
    last_call_result.write(amount_burnt);

    return ();
}
