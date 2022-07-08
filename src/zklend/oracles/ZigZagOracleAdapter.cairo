# SPDX-License-Identifier: BUSL-1.1

# ZigZagOracleAdapter : IPriceOracleSource

%lang starknet

from zklend.interfaces.third_parties.IZigZagOracle import IZigZagOracle
from zklend.libraries.SafeMath import SafeMath_div, SafeMath_mul

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

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_oracle : felt):
    oracle.write(_oracle)
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
    let (oracle_addr) = oracle.read()
    let (price) = IZigZagOracle.latest_price(contract_address=oracle_addr)
    let (scaled_price) = scale_price(price, oracle_addr)
    return (price=scaled_price)
end

# Get the price of the token in USD with 8 decimals and update timestamp
@view
func get_price_with_time{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    price : felt, update_time : felt
):
    alloc_locals

    let (oracle_addr) = oracle.read()
    let (price) = IZigZagOracle.latest_price(contract_address=oracle_addr)
    let (timestamp) = IZigZagOracle.latest_timestamp(contract_address=oracle_addr)
    let (scaled_price) = scale_price(price, oracle_addr)
    return (price=scaled_price, update_time=timestamp)
end

#
# Internal
#
func scale_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    price : felt, oracle_addr : felt
) -> (scaled_price : felt):
    alloc_locals

    # TODO: check if persisting `decimals` in constructor is more efficient
    let (decimals) = IZigZagOracle.decimals(contract_address=oracle_addr)
    if decimals == TARGET_DECIMALS:
        return (scaled_price=price)
    else:
        let (should_scale_up) = is_le_felt(decimals, TARGET_DECIMALS)
        if should_scale_up == TRUE:
            let (multiplier) = pow(10, TARGET_DECIMALS - decimals)
            let (scaled_price) = SafeMath_mul(price, multiplier)
            return (scaled_price=scaled_price)
        else:
            let (multiplier) = pow(10, decimals - TARGET_DECIMALS)
            let (scaled_price) = SafeMath_div(price, multiplier)
            return (scaled_price=scaled_price)
        end
    end
end
