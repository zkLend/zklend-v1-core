# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.interfaces.IInterestRateModel import IInterestRateModel
from zklend.interfaces.IPriceOracle import IPriceOracle
from zklend.interfaces.IZToken import IZToken
from zklend.libraries.Math import Math
from zklend.libraries.SafeCast import SafeCast
from zklend.libraries.SafeDecimalMath import SafeDecimalMath, SCALE
from zklend.libraries.SafeMath import SafeMath

from starkware.cairo.common.bitwise import bitwise_and, bitwise_or, bitwise_xor
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.math import assert_le_felt, assert_not_zero
from starkware.cairo.common.math_cmp import is_le_felt, is_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import (
    get_block_timestamp,
    get_caller_address,
    get_contract_address,
)

from openzeppelin.access.ownable import Ownable
from openzeppelin.upgrades.library import Proxy, Proxy_initialized
from openzeppelin.token.erc20.interfaces.IERC20 import IERC20

const SECONDS_PER_YEAR = 31536000

#
# Events
#

@event
func AccumulatorsSync(token : felt, lending_accumulator : felt, debt_accumulator : felt):
end

@event
func Deposit(user : felt, token : felt, face_amount : felt):
end

@event
func Withdrawal(user : felt, token : felt, face_amount : felt):
end

@event
func Borrowing(user : felt, token : felt, raw_amount : felt, face_amount : felt):
end

@event
func Repayment(user : felt, token : felt, raw_amount : felt, face_amount : felt):
end

@event
func CollateralEnabled(user : felt, token : felt):
end

@event
func CollateralDisabled(user : felt, token : felt):
end

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
    member reserve_factor : felt
    member last_update_timestamp : felt
    member lending_accumulator : felt
    member debt_accumulator : felt
    member current_lending_rate : felt
    member current_borrowing_rate : felt
    member raw_total_debt : felt
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

@storage_var
func raw_user_debts(user : felt, token : felt) -> (debt : felt):
end

#
# Upgradeability
#

@external
func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, _oracle : felt
):
    let (initialized) = Proxy_initialized.read()
    with_attr error_message("Proxy: contract already initialized"):
        assert initialized = FALSE
    end
    Proxy_initialized.write(TRUE)

    # TODO: check for zero addresses

    Ownable.initializer(owner)
    oracle.write(_oracle)

    return ()
end

@external
func upgrade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_implementation : felt
):
    Ownable.assert_only_owner()
    return Proxy._set_implementation_hash(new_implementation)
end

#
# Getters
#

@view
func get_reserve_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (data : ReserveData):
    let (reserve) = reserves.read(token)
    return (data=reserve)
end

# TODO: refactor `get_lending_accumulator` and `get_debt_accumulator` to reduce duplicated code
@view
func get_lending_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
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
        return (res=reserve.lending_accumulator)
    else:
        # Apply simple interest
        let (time_diff) = SafeMath.sub(block_timestamp, reserve.last_update_timestamp)

        # (current_lending_rate * time_diff / SECONDS_PER_YEAR + 1) * accumulator
        let (temp_1) = SafeMath.mul(reserve.current_lending_rate, time_diff)
        let (temp_2) = SafeMath.div(temp_1, SECONDS_PER_YEAR)
        let (temp_3) = SafeMath.add(temp_2, SCALE)
        let (latest_accumulator) = SafeDecimalMath.mul(temp_3, reserve.lending_accumulator)

        return (res=latest_accumulator)
    end
end

@view
func get_debt_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
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
        return (res=reserve.debt_accumulator)
    else:
        # Apply simple interest
        let (time_diff) = SafeMath.sub(block_timestamp, reserve.last_update_timestamp)

        # (current_borrowing_rate * time_diff / SECONDS_PER_YEAR + 1) * accumulator
        let (temp_1) = SafeMath.mul(reserve.current_borrowing_rate, time_diff)
        let (temp_2) = SafeMath.div(temp_1, SECONDS_PER_YEAR)
        let (temp_3) = SafeMath.add(temp_2, SCALE)
        let (latest_accumulator) = SafeDecimalMath.mul(temp_3, reserve.debt_accumulator)

        return (res=latest_accumulator)
    end
end

@view
func get_total_debt_for_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (debt : felt):
    alloc_locals

    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not enabled"):
        assert_not_zero(reserve.enabled)
    end

    let (debt_accumulator) = get_debt_accumulator(token)
    let (scaled_up_debt) = SafeDecimalMath.mul(reserve.raw_total_debt, debt_accumulator)
    return (debt=scaled_up_debt)
end

@view
func get_user_debt_for_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user : felt, token : felt
) -> (debt : felt):
    alloc_locals

    let (debt_accumulator) = get_debt_accumulator(token)
    let (raw_debt) = raw_user_debts.read(user, token)

    let (scaled_up_debt) = SafeDecimalMath.mul(raw_debt, debt_accumulator)
    return (debt=scaled_up_debt)
end

@view
func get_collateral_usage{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user : felt
) -> (usage : felt):
    let (map) = collateral_usages.read(user)
    return (usage=map)
end

@view
func is_user_undercollateralized{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt) -> (is_undercollateralized : felt):
    let (user_not_undercollateralized) = is_not_undercollateralized(user)

    if user_not_undercollateralized == TRUE:
        return (is_undercollateralized=FALSE)
    else:
        return (is_undercollateralized=TRUE)
    end
end

#
# External
#

@external
func deposit{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    alloc_locals

    let (caller) = get_caller_address()
    let (this_address) = get_contract_address()

    let (_, updated_debt_accumulator) = update_accumulators(token)

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

    # Updates interest rate
    # TODO: check if there's a way to persist only one field (using syscall directly?)
    let (reserve_balance_before_u256) = IERC20.balanceOf(
        contract_address=token, account=this_address
    )
    let (reserve_balance_before) = SafeCast.uint256_to_felt(reserve_balance_before_u256)
    let (reserve_balance_after) = SafeMath.add(reserve_balance_before, amount)
    let (scaled_up_total_debt) = SafeDecimalMath.mul(
        reserve.raw_total_debt, updated_debt_accumulator
    )
    let (new_lending_rate, new_borrowing_rate) = IInterestRateModel.get_interest_rates(
        contract_address=reserve.interest_rate_model,
        reserve_balance=reserve_balance_after,
        total_debt=scaled_up_total_debt,
    )
    reserves.write(
        token,
        ReserveData(
        enabled=reserve.enabled,
        decimals=reserve.decimals,
        z_token_address=reserve.z_token_address,
        interest_rate_model=reserve.interest_rate_model,
        collateral_factor=reserve.collateral_factor,
        borrow_factor=reserve.borrow_factor,
        reserve_factor=reserve.reserve_factor,
        last_update_timestamp=reserve.last_update_timestamp,
        lending_accumulator=reserve.lending_accumulator,
        debt_accumulator=reserve.debt_accumulator,
        current_lending_rate=new_lending_rate,
        current_borrowing_rate=new_borrowing_rate,
        raw_total_debt=reserve.raw_total_debt,
        ),
    )

    Deposit.emit(caller, token, amount)

    # Takes token from user

    let (amount_u256 : Uint256) = SafeCast.felt_to_uint256(amount)
    let (transfer_success) = IERC20.transferFrom(
        contract_address=token, sender=caller, recipient=this_address, amount=amount_u256
    )
    with_attr error_message("Market: transferFrom failed"):
        assert_not_zero(transfer_success)
    end

    # Mints ZToken to user
    IZToken.mint(contract_address=reserve.z_token_address, to=caller, amount=amount)

    return ()
end

@external
func withdraw{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    with_attr error_message("Market: zero amount"):
        assert_not_zero(amount)
    end

    return withdraw_internal(token, amount)
end

@external
func withdraw_all{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt):
    return withdraw_internal(token, 0)
end

@external
func borrow{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    alloc_locals

    let (caller) = get_caller_address()
    let (this_address) = get_contract_address()

    let (_, updated_debt_accumulator) = update_accumulators(token)

    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not enabled"):
        assert_not_zero(reserve.enabled)
    end

    let (scaled_down_amount) = SafeDecimalMath.div(amount, updated_debt_accumulator)
    let (raw_total_debt_after) = SafeMath.add(reserve.raw_total_debt, scaled_down_amount)

    # Updates user debt data
    let (raw_user_debt_before) = raw_user_debts.read(caller, token)
    let (raw_user_debt_after) = SafeMath.add(raw_user_debt_before, scaled_down_amount)
    raw_user_debts.write(caller, token, raw_user_debt_after)

    # Updates interest rate
    # TODO: check if there's a way to persist only one field (using syscall directly?)
    let (reserve_balance_before_u256) = IERC20.balanceOf(
        contract_address=token, account=this_address
    )
    let (reserve_balance_before) = SafeCast.uint256_to_felt(reserve_balance_before_u256)
    let (reserve_balance_after) = SafeMath.sub(reserve_balance_before, amount)
    let (scaled_up_total_debt_after) = SafeDecimalMath.mul(
        raw_total_debt_after, updated_debt_accumulator
    )
    let (new_lending_rate, new_borrowing_rate) = IInterestRateModel.get_interest_rates(
        contract_address=reserve.interest_rate_model,
        reserve_balance=reserve_balance_after,
        total_debt=scaled_up_total_debt_after,
    )
    reserves.write(
        token,
        ReserveData(
        enabled=reserve.enabled,
        decimals=reserve.decimals,
        z_token_address=reserve.z_token_address,
        interest_rate_model=reserve.interest_rate_model,
        collateral_factor=reserve.collateral_factor,
        borrow_factor=reserve.borrow_factor,
        reserve_factor=reserve.reserve_factor,
        last_update_timestamp=reserve.last_update_timestamp,
        lending_accumulator=reserve.lending_accumulator,
        debt_accumulator=reserve.debt_accumulator,
        current_lending_rate=new_lending_rate,
        current_borrowing_rate=new_borrowing_rate,
        raw_total_debt=raw_total_debt_after,
        ),
    )

    Borrowing.emit(caller, token, scaled_down_amount, amount)

    # It's easier to post-check collateralization factor
    with_attr error_message("Market: insufficient collateral"):
        assert_not_undercollateralized(caller)
    end

    #
    # Interactions
    #

    let (amount_u256 : Uint256) = SafeCast.felt_to_uint256(amount)
    let (transfer_success) = IERC20.transfer(
        contract_address=token, recipient=caller, amount=amount_u256
    )
    with_attr error_message("Market: transfer failed"):
        assert_not_zero(transfer_success)
    end

    return ()
end

@external
func repay{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt, amount : felt
):
    alloc_locals

    with_attr error_message("Market: zero amount"):
        assert_not_zero(amount)
    end

    let (caller) = get_caller_address()

    let (raw_amount, face_amount) = repay_debt_route_internal(caller, caller, token, amount)
    Repayment.emit(caller, token, raw_amount, face_amount)

    return ()
end

@external
func repay_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(token : felt):
    alloc_locals

    let (caller) = get_caller_address()

    let (raw_amount, face_amount) = repay_debt_route_internal(caller, caller, token, 0)
    Repayment.emit(caller, token, raw_amount, face_amount)

    return ()
end

@external
func enable_collateral{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt):
    alloc_locals

    let (caller) = get_caller_address()

    # Technically we don't need `reserve` here but we need to check existence
    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not found"):
        assert_not_zero(reserve.z_token_address)
    end

    let (reserve_index) = reserve_indices.read(token)

    set_collateral_usage(caller, reserve_index, TRUE)

    CollateralEnabled.emit(caller, token)

    return ()
end

@external
func disable_collateral{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt):
    alloc_locals

    let (caller) = get_caller_address()

    # Technically we don't need `reserve` here but we need to check existence
    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not found"):
        assert_not_zero(reserve.z_token_address)
    end

    let (reserve_index) = reserve_indices.read(token)

    set_collateral_usage(caller, reserve_index, FALSE)

    # It's easier to post-check collateralization factor
    with_attr error_message("Market: insufficient collateral"):
        assert_not_undercollateralized(caller)
    end

    CollateralDisabled.emit(caller, token)

    return ()
end

# With the current design, liquidators are responsible for calculating the maximum amount allowed.
# We simply check collteralization factor is below one after liquidation.
# TODO: calculate max amount on-chain because compute is cheap on StarkNet.
@external
func liquidate{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt, debt_token : felt, amount : felt, collateral_token : felt):
    alloc_locals

    let (caller) = get_caller_address()

    let (debt_reserve) = reserves.read(debt_token)
    let (collateral_reserve) = reserves.read(collateral_token)
    with_attr error_message("Market: reserve not enabled"):
        assert_not_zero(debt_reserve.enabled)
        assert_not_zero(collateral_reserve.enabled)
    end

    # Liquidator repays debt for user
    repay_debt_route_internal(caller, user, debt_token, amount)

    # Can only take from assets being used as collateral
    let (is_collateral) = is_used_as_collateral(user, 0)
    with_attr error_message("Market: cannot withdraw non-collateral token"):
        assert is_collateral = TRUE
    end

    # Liquidator withdraws collateral from user
    # TODO: account for liquidation bonus
    let (oracle_addr) = oracle.read()
    let (debt_token_price) = IPriceOracle.get_price(contract_address=oracle_addr, token=debt_token)
    let (collateral_token_price) = IPriceOracle.get_price(
        contract_address=oracle_addr, token=collateral_token
    )
    let (debt_value_repaid) = SafeDecimalMath.mul_decimals(
        debt_token_price, amount, debt_reserve.decimals
    )
    let (equivalent_collateral_amount) = SafeDecimalMath.div_decimals(
        debt_value_repaid, collateral_token_price, collateral_reserve.decimals
    )
    IZToken.move(
        contract_address=collateral_reserve.z_token_address,
        from_account=user,
        to_account=caller,
        amount=equivalent_collateral_amount,
    )

    # Checks user collateralization factor after liquidation
    with_attr error_message("Market: invalid liquidation"):
        assert_undercollateralized(user)
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
    reserve_factor : felt,
):
    Ownable.assert_only_owner()

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

    # Reserve factor must be zero since it's not yet implemented
    # TODO: remove this after reserve factor is implemented
    with_attr error_message("Market: reserve factor not zero"):
        assert reserve_factor = 0
    end

    # TODO: check `z_token` has the same `decimals`
    # TODO: check `decimals` range
    let (decimals) = IERC20.decimals(contract_address=token)

    # Checks underlying token of the Z token contract
    let (z_token_underlying) = IZToken.underlying_token(contract_address=z_token)
    with_attr error_message("Market: underlying token mismatch"):
        assert z_token_underlying = token
    end

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
        reserve_factor=reserve_factor,
        last_update_timestamp=0,
        lending_accumulator=SCALE,
        debt_accumulator=SCALE,
        current_lending_rate=0,
        current_borrowing_rate=0,
        raw_total_debt=0,
    )
    reserves.write(token, new_reserve)

    AccumulatorsSync.emit(token, SCALE, SCALE)

    let (current_reserve_count) = reserve_count.read()
    reserve_count.write(current_reserve_count + 1)
    reserve_tokens.write(current_reserve_count, token)
    reserve_indices.write(token, current_reserve_count)

    return ()
end

@external
func transfer_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_owner : felt
):
    return Ownable.transfer_ownership(new_owner)
end

@external
func renounce_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    return Ownable.renounce_ownership()
end

#
# Internal
#

func set_collateral_usage{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt, reserve_index : felt, use : felt):
    let (reserve_slot) = Math.shl(1, reserve_index)
    let (existing_usage) = collateral_usages.read(user)

    if use == TRUE:
        let (new_usage) = bitwise_or(existing_usage, reserve_slot)
    else:
        let (new_usage) = bitwise_xor(existing_usage, reserve_slot)
    end

    collateral_usages.write(user, new_usage)
    return ()
end

func is_used_as_collateral{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt, reserve_index : felt) -> (is_used : felt):
    let (reserve_slot) = Math.shl(1, reserve_index)
    let (existing_usage) = collateral_usages.read(user)

    let (and_result) = bitwise_and(existing_usage, reserve_slot)
    let (is_used) = is_not_zero(and_result)

    return (is_used=is_used)
end

func assert_undercollateralized{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt):
    let (user_not_undercollateralized) = is_not_undercollateralized(user)
    assert user_not_undercollateralized = FALSE
    return ()
end

func assert_not_undercollateralized{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt):
    let (user_not_undercollateralized) = is_not_undercollateralized(user)
    assert user_not_undercollateralized = TRUE
    return ()
end

func is_not_undercollateralized{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt) -> (res : felt):
    alloc_locals

    let (collateral_value, collateral_required) = calculate_user_collateral_data(user)
    let (is_not_undercollateralized) = is_le_felt(collateral_required, collateral_value)
    return (res=is_not_undercollateralized)
end

func calculate_user_collateral_data{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt) -> (collateral_value : felt, collateral_required : felt):
    let (reserve_cnt) = reserve_count.read()
    if reserve_cnt == 0:
        return (collateral_value=0, collateral_required=0)
    else:
        let (collateral_usage) = collateral_usages.read(user)

        let (collateral_value, collateral_required) = calculate_user_collateral_data_loop(
            user, collateral_usage, reserve_cnt, 0
        )

        return (collateral_value=collateral_value, collateral_required=collateral_required)
    end
end

# ASSUMPTION: `reserve_count` is not zero
func calculate_user_collateral_data_loop{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(user : felt, collateral_usage : felt, reserve_count : felt, reserve_index : felt) -> (
    collateral_value : felt, collateral_required : felt
):
    alloc_locals

    if reserve_index == reserve_count:
        return (collateral_value=0, collateral_required=0)
    end

    let (
        collateral_value_of_rest, collateral_required_of_rest
    ) = calculate_user_collateral_data_loop(
        user, collateral_usage, reserve_count, reserve_index + 1
    )
    local collateral_value_of_rest = collateral_value_of_rest
    local collateral_required_of_rest = collateral_required_of_rest

    let (reserve_slot) = Math.shl(1, reserve_index)
    let (reserve_slot_and) = bitwise_and(collateral_usage, reserve_slot)

    let (reserve_token) = reserve_tokens.read(reserve_index)

    let (current_collteral_required) = get_collateral_usd_value_required_for_token(
        user, reserve_token
    )
    let (total_collateral_required) = SafeMath.add(
        current_collteral_required, collateral_required_of_rest
    )

    if reserve_slot_and == FALSE:
        # Reserve not used as collateral
        return (
            collateral_value=collateral_value_of_rest, collateral_required=total_collateral_required
        )
    else:
        let (discounted_collteral_value) = get_user_collateral_usd_value_for_token(
            user, reserve_token
        )
        let (total_collateral_value) = SafeMath.add(
            discounted_collteral_value, collateral_value_of_rest
        )

        return (
            collateral_value=total_collateral_value, collateral_required=total_collateral_required
        )
    end
end

# ASSUMPTION: `token` is a valid reserve
func get_collateral_usd_value_required_for_token{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(user : felt, token : felt) -> (value : felt):
    alloc_locals

    let (reserve) = reserves.read(token)

    let (debt_value) = get_user_debt_usd_value_for_token(user, token)
    let (collateral_required) = SafeDecimalMath.div(debt_value, reserve.borrow_factor)

    return (value=collateral_required)
end

# ASSUMPTION: `token` is a valid reserve
func get_user_debt_usd_value_for_token{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(user : felt, token : felt) -> (value : felt):
    alloc_locals

    let (raw_debt_balance) = raw_user_debts.read(user, token)
    if raw_debt_balance == 0:
        return (value=0)
    end

    let (debt_accumulator) = get_debt_accumulator(token)
    let (scaled_up_debt_balance) = SafeDecimalMath.mul(raw_debt_balance, debt_accumulator)

    # Fetches price from oracle
    let (oracle_addr) = oracle.read()
    let (debt_price) = IPriceOracle.get_price(contract_address=oracle_addr, token=token)

    let (reserve) = reserves.read(token)

    let (debt_value) = SafeDecimalMath.mul_decimals(
        debt_price, scaled_up_debt_balance, reserve.decimals
    )

    return (value=debt_value)
end

# ASSUMPTION: `token` is a valid reserve
# ASSUMPTION: `token` is used by `user` as collateral
func get_user_collateral_usd_value_for_token{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(user : felt, token : felt) -> (value : felt):
    alloc_locals

    let (reserve) = reserves.read(token)

    # This value already reflects interests accured since last update
    let (collateral_balance) = IZToken.felt_balance_of(
        contract_address=reserve.z_token_address, account=user
    )

    # Fetches price from oracle
    let (oracle_addr) = oracle.read()
    let (collateral_price) = IPriceOracle.get_price(contract_address=oracle_addr, token=token)

    # `collateral_value` is represented in 8-decimal USD value
    let (collateral_value) = SafeDecimalMath.mul_decimals(
        collateral_price, collateral_balance, reserve.decimals
    )

    # Discounts value by collteral factor
    let (discounted_collteral_value) = SafeDecimalMath.mul(
        collateral_value, reserve.collateral_factor
    )

    return (value=discounted_collteral_value)
end

# `amount` with `0` means withdrawing all
func withdraw_internal{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
}(token : felt, amount : felt):
    alloc_locals

    # TODO: forbid `get_caller_address()` in non-external methods
    let (caller) = get_caller_address()
    let (this_address) = get_contract_address()

    let (_, updated_debt_accumulator) = update_accumulators(token)

    #
    # Checks
    #

    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not enabled"):
        assert_not_zero(reserve.enabled)
    end

    #
    # Effects
    #

    # NOTE: it's fine to call out to external contract here before state update since it's trusted
    let (amount_burnt) = burn_z_token_internal(reserve.z_token_address, caller, amount)

    # Updates interest rate
    # TODO: check if there's a way to persist only one field (using syscall directly?)
    let (reserve_balance_before_u256) = IERC20.balanceOf(
        contract_address=token, account=this_address
    )
    let (reserve_balance_before) = SafeCast.uint256_to_felt(reserve_balance_before_u256)
    let (reserve_balance_after) = SafeMath.sub(reserve_balance_before, amount_burnt)
    let (scaled_up_total_debt) = SafeDecimalMath.mul(
        reserve.raw_total_debt, updated_debt_accumulator
    )
    let (new_lending_rate, new_borrowing_rate) = IInterestRateModel.get_interest_rates(
        contract_address=reserve.interest_rate_model,
        reserve_balance=reserve_balance_after,
        total_debt=scaled_up_total_debt,
    )
    reserves.write(
        token,
        ReserveData(
        enabled=reserve.enabled,
        decimals=reserve.decimals,
        z_token_address=reserve.z_token_address,
        interest_rate_model=reserve.interest_rate_model,
        collateral_factor=reserve.collateral_factor,
        borrow_factor=reserve.borrow_factor,
        reserve_factor=reserve.reserve_factor,
        last_update_timestamp=reserve.last_update_timestamp,
        lending_accumulator=reserve.lending_accumulator,
        debt_accumulator=reserve.debt_accumulator,
        current_lending_rate=new_lending_rate,
        current_borrowing_rate=new_borrowing_rate,
        raw_total_debt=reserve.raw_total_debt,
        ),
    )

    Withdrawal.emit(caller, token, amount_burnt)

    #
    # Interactions
    #

    # Gives underlying tokens to user
    let (amount_burnt_u256 : Uint256) = SafeCast.felt_to_uint256(amount_burnt)
    let (transfer_success) = IERC20.transfer(
        contract_address=token, recipient=caller, amount=amount_burnt_u256
    )
    with_attr error_message("Market: transfer failed"):
        assert_not_zero(transfer_success)
    end

    # It's easier to post-check collateralization factor
    # TODO: skip the check if not used as collateral
    with_attr error_message("Market: insufficient collateral"):
        assert_not_undercollateralized(caller)
    end

    return ()
end

# `amount` with `0` means repaying all
func repay_debt_route_internal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    repayer : felt, beneficiary : felt, token : felt, amount : felt
) -> (raw_amount : felt, face_amount : felt):
    alloc_locals

    let (reserve) = reserves.read(token)
    with_attr error_message("Market: reserve not enabled"):
        assert_not_zero(reserve.enabled)
    end

    let (updated_debt_accumulator) = get_debt_accumulator(token)

    if amount == 0:
        let (user_raw_debt) = raw_user_debts.read(beneficiary, token)
        let (repay_amount) = SafeDecimalMath.mul(user_raw_debt, updated_debt_accumulator)

        repay_debt_internal(repayer, beneficiary, token, repay_amount, user_raw_debt)

        return (raw_amount=user_raw_debt, face_amount=repay_amount)
    else:
        let (raw_amount) = SafeDecimalMath.div(amount, updated_debt_accumulator)

        repay_debt_internal(repayer, beneficiary, token, amount, raw_amount)

        return (raw_amount=raw_amount, face_amount=amount)
    end
end

# ASSUMPTION: `repay_amount` = `raw_amount` * Debt Accumulator
# ASSUMPTION: it's always called by `repay_debt_route_internal`
func repay_debt_internal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    repayer : felt, beneficiary : felt, token : felt, repay_amount : felt, raw_amount : felt
):
    alloc_locals

    let (this_address) = get_contract_address()

    let (_, updated_debt_accumulator) = update_accumulators(token)

    #
    # Checks
    #

    # No need to check `enabled` as it's already done in `repay_debt_route_internal`
    let (reserve) = reserves.read(token)

    # No need to check if user is overpaying, as `SafeMath.sub` below will fail anyways
    # No need to check collateral value. Always allow repaying even if it's undercollateralized

    #
    # Effects
    #

    let (raw_total_debt_after) = SafeMath.sub(reserve.raw_total_debt, raw_amount)

    # Updates user debt data
    let (raw_user_debt_before) = raw_user_debts.read(beneficiary, token)
    let (raw_user_debt_after) = SafeMath.sub(raw_user_debt_before, raw_amount)
    raw_user_debts.write(beneficiary, token, raw_user_debt_after)

    # Updates interest rate
    # TODO: check if there's a way to persist only one field (using syscall directly?)
    let (reserve_balance_before_u256) = IERC20.balanceOf(
        contract_address=token, account=this_address
    )
    let (reserve_balance_before) = SafeCast.uint256_to_felt(reserve_balance_before_u256)
    let (reserve_balance_after) = SafeMath.add(reserve_balance_before, repay_amount)
    let (scaled_up_total_debt_after) = SafeDecimalMath.mul(
        raw_total_debt_after, updated_debt_accumulator
    )
    let (new_lending_rate, new_borrowing_rate) = IInterestRateModel.get_interest_rates(
        contract_address=reserve.interest_rate_model,
        reserve_balance=reserve_balance_after,
        total_debt=scaled_up_total_debt_after,
    )
    reserves.write(
        token,
        ReserveData(
        enabled=reserve.enabled,
        decimals=reserve.decimals,
        z_token_address=reserve.z_token_address,
        interest_rate_model=reserve.interest_rate_model,
        collateral_factor=reserve.collateral_factor,
        borrow_factor=reserve.borrow_factor,
        reserve_factor=reserve.reserve_factor,
        last_update_timestamp=reserve.last_update_timestamp,
        lending_accumulator=reserve.lending_accumulator,
        debt_accumulator=reserve.debt_accumulator,
        current_lending_rate=new_lending_rate,
        current_borrowing_rate=new_borrowing_rate,
        raw_total_debt=raw_total_debt_after,
        ),
    )

    #
    # Interactions
    #

    # Takes token from user
    let (repay_amount_u256 : Uint256) = SafeCast.felt_to_uint256(repay_amount)
    let (transfer_success) = IERC20.transferFrom(
        contract_address=token, sender=repayer, recipient=this_address, amount=repay_amount_u256
    )
    with_attr error_message("Market: transfer failed"):
        assert_not_zero(transfer_success)
    end

    return ()
end

# `amount` with `0` means burning all
func burn_z_token_internal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    z_token : felt, user : felt, amount : felt
) -> (amount_burnt : felt):
    if amount == 0:
        let (amount_burnt) = IZToken.burn_all(contract_address=z_token, user=user)
        return (amount_burnt=amount_burnt)
    else:
        IZToken.burn(contract_address=z_token, user=user, amount=amount)
        return (amount_burnt=amount)
    end
end

func update_accumulators{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token : felt
) -> (lending_accumulator : felt, debt_accumulator : felt):
    alloc_locals

    let (block_timestamp) = get_block_timestamp()

    let (updated_lending_accumulator) = get_lending_accumulator(token)
    let (updated_debt_accumulator) = get_debt_accumulator(token)

    AccumulatorsSync.emit(token, updated_lending_accumulator, updated_debt_accumulator)

    # No need to check reserve existence since it's done in `get_lending_accumulator` and
    # `get_debt_accumulator`
    let (reserve) = reserves.read(token)

    # TODO: use a manually-written storage namespace for updating only relevant fields
    reserves.write(
        token,
        ReserveData(
        enabled=reserve.enabled,
        decimals=reserve.decimals,
        z_token_address=reserve.z_token_address,
        interest_rate_model=reserve.interest_rate_model,
        collateral_factor=reserve.collateral_factor,
        borrow_factor=reserve.borrow_factor,
        reserve_factor=reserve.reserve_factor,
        last_update_timestamp=block_timestamp,
        lending_accumulator=updated_lending_accumulator,
        debt_accumulator=updated_debt_accumulator,
        current_lending_rate=reserve.current_lending_rate,
        current_borrowing_rate=reserve.current_borrowing_rate,
        raw_total_debt=reserve.raw_total_debt,
        ),
    )

    return (
        lending_accumulator=updated_lending_accumulator, debt_accumulator=updated_debt_accumulator
    )
end
