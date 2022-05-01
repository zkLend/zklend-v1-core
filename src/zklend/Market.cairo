# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.interfaces.IInterestRateModel import IInterestRateModel
from zklend.interfaces.IPriceOracle import IPriceOracle
from zklend.interfaces.IZToken import IZToken
from zklend.libraries.Math import Math_shl
from zklend.libraries.SafeCast import SafeCast_felt_to_uint256
from zklend.libraries.SafeDecimalMath import (
    SafeDecimalMath_mul,
    SafeDecimalMath_mul_decimals,
    SCALE,
)
from zklend.libraries.SafeMath import SafeMath_add, SafeMath_div, SafeMath_mul, SafeMath_sub

from starkware.cairo.common.bitwise import bitwise_and, bitwise_or, bitwise_xor
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.math import assert_le_felt, assert_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import (
    get_block_timestamp,
    get_caller_address,
    get_contract_address,
)

from openzeppelin.access.ownable import Ownable_initializer, Ownable_only_owner
from openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from openzeppelin.utils.constants import FALSE, TRUE

const SECONDS_PER_YEAR = 31536000

#
# Structs
#

# TODO: compress small fields into bitmap
struct ReserveData:
    member enabled : felt
    member decimals : felt
    member z_token_address : felt
    member interest_rate_model : felt
    member collateral_factor : felt
    member borrow_factor : felt
    member last_update_timestamp : felt
    member accumulator : felt
    member current_lending_rate : felt
end

#
# Storage
#

@storage_var
func oracle() -> (oracle : felt):
end

@storage_var
func reserves(token : felt) -> (res : ReserveData):
end

@storage_var
func reserve_count() -> (count : felt):
end

@storage_var
func reserve_tokens(index : felt) -> (token : felt):
end

@storage_var
func reserve_indices(token : felt) -> (index : felt):
end

@storage_var
func collateral_usages(user : felt) -> (map : felt):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, _oracle : felt
):
    # TODO: check for zero addresses

    Ownable_initializer(owner)
    oracle.write(_oracle)

    return ()
end

#
# Getters
#

@view
func get_reserve_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (res : felt):
    alloc_locals

    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not enabled"):
        assert_not_zero(reserve.enabled)
    end

    let (block_timestamp) = get_block_timestamp()
    if reserve.last_update_timestamp == block_timestamp:
        # Accumulator already updated on the same block
        return (res=reserve.accumulator)
    else:
        # Apply simple interest
        let (time_diff) = SafeMath_sub(block_timestamp, reserve.last_update_timestamp)

        # (current_lending_rate * time_diff / SECONDS_PER_YEAR + 1) * accumulator
        let (temp_1) = SafeMath_mul(reserve.current_lending_rate, time_diff)
        let (temp_2) = SafeMath_div(temp_1, SECONDS_PER_YEAR)
        let (temp_3) = SafeMath_add(temp_2, SCALE)
        let (latest_accumulator) = SafeMath_mul(temp_3, reserve.accumulator)

        return (res=latest_accumulator)
    end
end

@view
func get_collateral_usage{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user : felt
) -> (usage : felt):
    let (map) = collateral_usages.read(user)
    return (usage=map)
end

#
# External
#

@external
func deposit{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    let (caller) = get_caller_address()
    let (this_address) = get_contract_address()

    #
    # Checks
    #
    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not enabled"):
        assert_not_zero(reserve.enabled)
    end

    let (reserve_index) = reserve_indices.read(token)

    #
    # Interactions
    #

    # TODO: update reserve data

    # Takes token from user

    let (amount_u256 : Uint256) = SafeCast_felt_to_uint256(amount)
    let (transfer_success) = IERC20.transferFrom(
        contract_address=token, sender=caller, recipient=this_address, amount=amount_u256
    )
    with_attr error_message("Market: transferFrom failed"):
        assert_not_zero(transfer_success)
    end

    # Mints ZToken to user
    let (is_first_deposit) = IZToken.mint(
        contract_address=reserve.z_token_address, to=caller, amount=amount
    )
    if is_first_deposit == TRUE:
        # Use deposit as collateral by default
        # TODO: add option to disable auto collateral usage
        set_collateral_usage(caller, reserve_index, TRUE)
        return ()
    end

    return ()
end

@external
func withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt, amount : felt
):
    let (caller) = get_caller_address()
    let (this_address) = get_contract_address()

    #
    # Checks
    #
    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not enabled"):
        assert_not_zero(reserve.enabled)
    end

    #
    # Interactions
    #

    # TODO: update reserve data

    # Burns token of user
    IZToken.burn(contract_address=reserve.z_token_address, user=caller, amount=amount)

    # Gives underlying tokens to user
    let (amount_u256 : Uint256) = SafeCast_felt_to_uint256(amount)
    let (transfer_success) = IERC20.transfer(
        contract_address=token, recipient=caller, amount=amount_u256
    )
    with_attr error_message("Market: transfer failed"):
        assert_not_zero(transfer_success)
    end

    return ()
end

@external
func borrow{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    alloc_locals

    let (caller) = get_caller_address()

    #
    # Checks
    #
    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not enabled"):
        assert_not_zero(reserve.enabled)
    end

    # Fetches price from oracle
    let (oracle_addr) = oracle.read()
    let (loan_token_price) = IPriceOracle.get_price(contract_address=oracle_addr, token=token)

    let (loan_usd_value) = SafeDecimalMath_mul_decimals(loan_token_price, amount, reserve.decimals)
    let (total_collateral_value) = calculate_user_collateral_value(caller)
    let (discounted_collteral_value) = SafeDecimalMath_mul(
        total_collateral_value, reserve.borrow_factor
    )

    # TODO: take collateral factor and borrow factor into account
    with_attr error_message("Market: insufficient collateral"):
        assert_le_felt(loan_usd_value, discounted_collteral_value)
    end

    #
    # Effects
    #

    # TODO: update reserve data

    # TODO: update debt data

    #
    # Interactions
    #

    let (amount_u256 : Uint256) = SafeCast_felt_to_uint256(amount)
    let (transfer_success) = IERC20.transfer(
        contract_address=token, recipient=caller, amount=amount_u256
    )
    with_attr error_message("Market: transfer failed"):
        assert_not_zero(transfer_success)
    end

    return ()
end

@external
func add_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt,
    z_token : felt,
    interest_rate_model : felt,
    collateral_factor : felt,
    borrow_factor : felt,
):
    Ownable_only_owner()

    #
    # Checks
    #
    with_attr error_message("Market: zero token"):
        assert_not_zero(token)
    end
    with_attr error_message("Market: zero z_token"):
        assert_not_zero(z_token)
    end
    with_attr error_message("Market: zero interest_rate_model"):
        assert_not_zero(interest_rate_model)
    end

    let (existing_reserve) = reserves.read(token)
    with_attr error_message("Market: reserve already exists"):
        assert existing_reserve.z_token_address = 0
    end

    # Checks collateral_factor range
    with_attr error_message("Market: collteral factor out of range"):
        assert_le_felt(collateral_factor, SCALE)
    end

    # Checks borrow_factor range
    with_attr error_message("Market: borrow factor out of range"):
        assert_le_felt(borrow_factor, SCALE)
    end

    # TODO: check `z_token` has the same `decimals`
    # TODO: check `decimals` range
    let (decimals) = IERC20.decimals(contract_address=token)

    # TODO: limit reserve count

    #
    # Effects
    #
    let new_reserve = ReserveData(
        enabled=TRUE,
        decimals=decimals,
        z_token_address=z_token,
        interest_rate_model=interest_rate_model,
        collateral_factor=collateral_factor,
        borrow_factor=borrow_factor,
        last_update_timestamp=0,
        accumulator=SCALE,
        current_lending_rate=0,
    )
    reserves.write(token, new_reserve)

    let (current_reserve_count) = reserve_count.read()
    reserve_count.write(current_reserve_count + 1)
    reserve_tokens.write(current_reserve_count, token)
    reserve_indices.write(token, current_reserve_count)

    return ()
end

#
# Internal
#

func set_collateral_usage{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt, reserve_index : felt, use : felt):
    let (reserve_slot) = Math_shl(1, reserve_index)
    let (existing_usage) = collateral_usages.read(user)

    if use == TRUE:
        let (new_usage) = bitwise_or(existing_usage, reserve_slot)
    else:
        let (new_usage) = bitwise_xor(existing_usage, reserve_slot)
    end

    collateral_usages.write(user, new_usage)
    return ()
end

func calculate_user_collateral_value{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt) -> (value : felt):
    # TODO: also calculate and account for debt

    let (reserve_cnt) = reserve_count.read()
    if reserve_cnt == 0:
        return (value=0)
    else:
        let (collateral_usage) = collateral_usages.read(user)

        let (total_collateral_value) = calculate_user_collateral_value_loop(
            user, collateral_usage, reserve_cnt, 0
        )

        return (value=total_collateral_value)
    end
end

# ASSUMPTION: `reserve_count` is not zero
func calculate_user_collateral_value_loop{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt, collateral_usage : felt, reserve_count : felt, reserve_index : felt) -> (
    value : felt
):
    alloc_locals

    if reserve_index == reserve_count:
        return (value=0)
    end

    let (value_of_rest) = calculate_user_collateral_value_loop(
        user, collateral_usage, reserve_count, reserve_index + 1
    )
    local value_of_rest = value_of_rest

    let (reserve_slot) = Math_shl(1, reserve_index)
    let (reserve_slot_and) = bitwise_and(collateral_usage, reserve_slot)

    if reserve_slot_and == FALSE:
        # Reserve not used as collateral
        return (value=value_of_rest)
    else:
        let (reserve_token) = reserve_tokens.read(reserve_index)
        let (reserve) = reserves.read(reserve_token)

        # This value already reflects interests accured since last update
        let (collateral_balance) = IZToken.felt_balance_of(
            contract_address=reserve.z_token_address, account=user
        )

        # Fetches price from oracle
        let (oracle_addr) = oracle.read()
        let (collateral_price) = IPriceOracle.get_price(
            contract_address=oracle_addr, token=reserve_token
        )

        # `collateral_value` is represented in 8-decimal USD value
        let (collateral_value) = SafeDecimalMath_mul_decimals(
            collateral_price, collateral_balance, reserve.decimals
        )

        # Discounts value by collteral factor
        let (discounted_collteral_value) = SafeDecimalMath_mul(
            collateral_value, reserve.collateral_factor
        )

        return (value=value_of_rest + discounted_collteral_value)
    end
end
