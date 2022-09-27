// SPDX-License-Identifier: MIT

%lang starknet

@contract_interface
namespace IPriceOracleSource {
    func get_price() -> (price: felt) {
    }

    func get_price_with_time() -> (price: felt, update_time: felt) {
    }
}
