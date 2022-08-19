# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.internals.Market.functions import External, View
from zklend.internals.Market.structs import Structs

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin

#
# Upgradeability
#

@external
func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, _oracle : felt
):
    return External.initializer(owner, _oracle)
end

@external
func upgrade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_implementation : felt
):
    return External.upgrade(new_implementation)
end

#
# Getters
#

@view
func get_reserve_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (data : Structs.ReserveData):
    return View.get_reserve_data(token)
end

@view
func get_lending_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (res : felt):
    return View.get_lending_accumulator(token)
end

@view
func get_debt_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (res : felt):
    return View.get_debt_accumulator(token)
end

# WARN: this must be run BEFORE adjusting the accumulators (otherwise always returns 0)
@view
func get_pending_treasury_amount{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (res : felt):
    return View.get_pending_treasury_amount(token)
end

@view
func get_total_debt_for_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (debt : felt):
    return View.get_total_debt_for_token(token)
end

@view
func get_user_debt_for_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user : felt, token : felt
) -> (debt : felt):
    return View.get_user_debt_for_token(user, token)
end

@view
func get_user_flags{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user : felt
) -> (map : felt):
    return View.get_user_flags(user)
end

@view
func is_user_undercollateralized{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt, apply_borrow_factor : felt) -> (is_undercollateralized : felt):
    return View.is_user_undercollateralized(user, apply_borrow_factor)
end

@view
func is_collateral_enabled{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt, token : felt) -> (enabled : felt):
    return View.is_collateral_enabled(user, token)
end

@view
func user_has_debt{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt) -> (has_debt : felt):
    return View.user_has_debt(user)
end

#
# Permissionless entrypoints
#

@external
func deposit{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    return External.deposit(token, amount)
end

@external
func withdraw{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    return External.withdraw(token, amount)
end

@external
func withdraw_all{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt):
    return External.withdraw_all(token)
end

@external
func borrow{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    return External.borrow(token, amount)
end

@external
func repay{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    return External.repay(token, amount)
end

@external
func repay_all{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt):
    return External.repay_all(token)
end

@external
func enable_collateral{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt):
    return External.enable_collateral(token)
end

@external
func disable_collateral{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt):
    return External.disable_collateral(token)
end

# With the current design, liquidators are responsible for calculating the maximum amount allowed.
# We simply check collteralization factor is below one after liquidation.
# TODO: calculate max amount on-chain because compute is cheap on StarkNet.
@external
func liquidate{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt, debt_token : felt, amount : felt, collateral_token : felt):
    return External.liquidate(user, debt_token, amount, collateral_token)
end

@external
func flash_loan{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    receiver : felt, token : felt, amount : felt, calldata_len : felt, calldata : felt*
):
    return External.flash_loan(receiver, token, amount, calldata_len, calldata)
end

#
# Permissioned entrypoints
#

@external
func add_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt,
    z_token : felt,
    interest_rate_model : felt,
    collateral_factor : felt,
    borrow_factor : felt,
    reserve_factor : felt,
    flash_loan_fee : felt,
    liquidation_bonus : felt,
):
    return External.add_reserve(
        token,
        z_token,
        interest_rate_model,
        collateral_factor,
        borrow_factor,
        reserve_factor,
        flash_loan_fee,
        liquidation_bonus,
    )
end

@external
func set_reserve_factor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt, new_reserve_factor : felt
):
    return External.set_reserve_factor(token, new_reserve_factor)
end

@external
func set_liquidation_bonus{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt, new_liquidation_bonus : felt
):
    return External.set_liquidation_bonus(token, new_liquidation_bonus)
end

@external
func set_treasury{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_treasury : felt
):
    return External.set_treasury(new_treasury)
end

@external
func transfer_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_owner : felt
):
    return External.transfer_ownership(new_owner)
end

@external
func renounce_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    return External.renounce_ownership()
end
