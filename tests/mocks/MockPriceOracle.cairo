# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

#
# Storage
#

@storage_var
func prices(token : felt) -> (price : felt):
end

#
# Getters
#

# Get the price of the token in USD with 8 decimals
@view
func get_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(token : felt) -> (
    price : felt
):
    let (price) = prices.read(token)
    return (price=price)
end

#
# External
#

@external
func set_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt, price : felt
):
    prices.write(token, price)
    return ()
end
