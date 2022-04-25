# SPDX-License-Identifier: BUSL-1.1

# MockZigZagOracle: IZigZagOracle

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

#
# Structs
#
struct PriceData:
    member price : felt
    member update_time : felt
end

#
# Storage
#

@storage_var
func _decimals() -> (decimals : felt):
end

@storage_var
func price_data() -> (data : PriceData):
end

#
# Getters
#

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    decimals : felt
):
    let (decimals) = _decimals.read()
    return (decimals=decimals)
end

@view
func latest_timestamp{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    ts : felt
):
    let (data) = price_data.read()
    return (ts=data.update_time)
end

@view
func latest_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    price : felt
):
    let (data) = price_data.read()
    return (price=data.price)
end

#
# External
#

@external
func set_decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    decimals : felt
):
    _decimals.write(decimals)
    return ()
end

@external
func set_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    price : felt, update_time : felt
):
    price_data.write(PriceData(price=price, update_time=update_time))
    return ()
end
