// SPDX-License-Identifier: BUSL-1.1

// MockPriceOracle : IPriceOracle

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

//
// Structs
//
struct PriceData {
    price: felt,
    update_time: felt,
}

//
// Storage
//

@storage_var
func prices(token: felt) -> (data: PriceData) {
}

//
// Getters
//

// Get the price of the token in USD with 8 decimals
@view
func get_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(token: felt) -> (
    price: felt
) {
    let (data) = prices.read(token);
    return (price=data.price);
}

@view
func get_price_with_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt
) -> (price: felt, update_time: felt) {
    let (data) = prices.read(token);
    return (price=data.price, update_time=data.update_time);
}

//
// External
//

@external
func set_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token: felt, price: felt, update_time: felt
) {
    prices.write(token, PriceData(price=price, update_time=update_time));
    return ();
}
