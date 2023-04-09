// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.interfaces.IPriceOracleSource import IPriceOracleSource

from starkware.cairo.common.cairo_builtins import HashBuiltin

from openzeppelin.access.ownable.library import Ownable

@storage_var
func sources(token: felt) -> (source: felt) {
}

@event
func TokenSourceChanged(token: felt, source: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
    Ownable.initializer(owner);
    return ();
}

@view
func get_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(token: felt) -> (
    price: felt
) {
    let (source) = sources.read(token);
    let (price) = IPriceOracleSource.get_price(contract_address=source);
    return (price=price);
}

@view
func get_price_with_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt
) -> (price: felt, update_time: felt) {
    let (source) = sources.read(token);
    let (price, update_time) = IPriceOracleSource.get_price_with_time(contract_address=source);
    return (price=price, update_time=update_time);
}

@external
func set_token_source{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt, source: felt
) {
    Ownable.assert_only_owner();

    sources.write(token, source);

    TokenSourceChanged.emit(token, source);

    return ();
}
