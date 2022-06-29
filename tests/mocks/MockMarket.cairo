# SPDX-License-Identifier: BUSL-1.1

# MockMarket : IMarket

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from zklend.interfaces.IZToken import IZToken

#
# Storage
#

@storage_var
func lending_accumulator(token : felt) -> (res : felt):
end

@storage_var
func debt_accumulator(token : felt) -> (res : felt):
end

@storage_var
func user_undercollateralized(user : felt) -> (res : felt):
end

#
# Getters
#

@view
func get_lending_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (res : felt):
    let (res) = lending_accumulator.read(token)
    return (res=res)
end

@view
func get_debt_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (res : felt):
    let (res) = debt_accumulator.read(token)
    return (res=res)
end

@view
func is_user_undercollateralized{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user : felt
) -> (is_undercollateralized : felt):
    let (res) = user_undercollateralized.read(user)
    return (is_undercollateralized=res)
end

#
# External
#

@external
func set_lending_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt, value : felt
):
    lending_accumulator.write(token, value)
    return ()
end

@external
func set_debt_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt, value : felt
):
    debt_accumulator.write(token, value)
    return ()
end

@external
func set_user_undercollateralized{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(user : felt, value : felt):
    user_undercollateralized.write(user, value)
    return ()
end

@external
func mint_z_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    z_token : felt, to : felt, amount : felt
):
    IZToken.mint(contract_address=z_token, to=to, amount=amount)
    return ()
end
