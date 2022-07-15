# SPDX-License-Identifier: BUSL-1.1

# EmpiricOracleAdapter : IPriceOracleSource

%lang starknet

from zklend.interfaces.third_parties.IEmpiricOracle import IEmpiricOracle
from zklend.libraries.SafeMath import SafeMath

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.pow import pow

const TARGET_DECIMALS = 8

#
# Storage
#

@storage_var
func oracle() -> (oracle : felt):
end

@storage_var
func pair() -> (oracle : felt):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _oracle : felt, _pair : felt
):
    oracle.write(_oracle)
    pair.write(_pair)
    return ()
end

#
# Getters
#

# Get the price of the token in USD with 8 decimals
@view
func get_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    price : felt
):
    let (price, _) = get_data()
    return (price=price)
end

# Get the price of the token in USD with 8 decimals and update timestamp
@view
func get_price_with_time{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    price : felt, update_time : felt
):
    let (price, update_time) = get_data()
    return (price=price, update_time=update_time)
end

#
# Internal
#
func get_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    price : felt, update_time : felt
):
    alloc_locals

    let (oracle_addr) = oracle.read()
    let (pair_key) = pair.read()

    let (price, decimals, last_updated_timestamp, _) = IEmpiricOracle.get_value(
        contract_address=oracle_addr, key=pair_key, aggregation_mode='median'
    )

    let (scaled_price) = scale_price(price, decimals)
    return (price=scaled_price, update_time=last_updated_timestamp)
end

func scale_price{range_check_ptr}(price : felt, decimals : felt) -> (scaled_price : felt):
    if decimals == TARGET_DECIMALS:
        return (scaled_price=price)
    else:
        let (should_scale_up) = is_le_felt(decimals, TARGET_DECIMALS)
        if should_scale_up == TRUE:
            let (multiplier) = pow(10, TARGET_DECIMALS - decimals)
            let (scaled_price) = SafeMath.mul(price, multiplier)
            return (scaled_price=scaled_price)
        else:
            let (multiplier) = pow(10, decimals - TARGET_DECIMALS)
            let (scaled_price) = SafeMath.div(price, multiplier)
            return (scaled_price=scaled_price)
        end
    end
end
