// SPDX-License-Identifier: MIT

%lang starknet

@contract_interface
namespace IPriceOracleSource {
    // Get the price of the token in USD with 8 decimals
    func get_price() -> (price: felt) {
    }

    // Get the price of the token in USD with 8 decimals and update timestamp
    func get_price_with_time() -> (price: felt, update_time: felt) {
    }
}
