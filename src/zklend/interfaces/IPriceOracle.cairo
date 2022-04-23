# SPDX-License-Identifier: BUSL-1.1

%lang starknet

@contract_interface
namespace IPriceOracle:
    # Get the price of the token in USD with 8 decimals
    func get_price(token : felt) -> (price : felt):
    end
end
