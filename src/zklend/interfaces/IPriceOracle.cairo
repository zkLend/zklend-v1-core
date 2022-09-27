// SPDX-License-Identifier: MIT

%lang starknet

@contract_interface
namespace IPriceOracle {
    func get_price(token: felt) -> (price: felt) {
    }

    func get_price_with_time(token: felt) -> (price: felt, update_time: felt) {
    }
}
