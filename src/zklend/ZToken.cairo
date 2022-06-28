# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.interfaces.IMarket import IMarket
from zklend.libraries.SafeCast import SafeCast_felt_to_uint256, SafeCast_uint256_to_felt
from zklend.libraries.SafeDecimalMath import SafeDecimalMath_div, SafeDecimalMath_mul
from zklend.libraries.SafeMath import SafeMath_add, SafeMath_div, SafeMath_mul, SafeMath_sub

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.token.erc20.library import ERC20_initializer, Transfer
from openzeppelin.utils.constants import FALSE, TRUE

#
# Storage
#

@storage_var
func market() -> (res : felt):
end

@storage_var
func underlying() -> (res : felt):
end

@storage_var
func raw_total_supply() -> (total_supply : felt):
end

@storage_var
func raw_balances(account : felt) -> (balance : felt):
end

#
# Constructor
#
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _market : felt, _underlying : felt, _name : felt, _symbol : felt, _decimals : felt
):
    with_attr error_message("ZToken: zero address"):
        assert_not_zero(_market)
        assert_not_zero(_underlying)
    end

    market.write(_market)
    underlying.write(_underlying)

    ERC20_initializer(_name, _symbol, _decimals)
    return ()
end

#
# Getters
#

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    total_supply : Uint256
):
    alloc_locals

    let (accumulator) = get_accumulator()

    let (supply) = raw_total_supply.read()
    let (scaled_up_supply) = SafeDecimalMath_mul(supply, accumulator)
    let (scaled_up_supply_u256 : Uint256) = SafeCast_felt_to_uint256(scaled_up_supply)

    return (total_supply=scaled_up_supply_u256)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (balance : Uint256):
    let (scaled_up_balance) = felt_balance_of(account)
    let (scaled_up_balance_u256 : Uint256) = SafeCast_felt_to_uint256(scaled_up_balance)

    return (balance=scaled_up_balance_u256)
end

@view
func felt_balance_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (balance : felt):
    alloc_locals

    let (accumulator) = get_accumulator()

    let (balance) = raw_balances.read(account)
    let (scaled_up_balance) = SafeDecimalMath_mul(balance, accumulator)

    return (balance=scaled_up_balance)
end

#
# External
#

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : Uint256
) -> (success : felt):
    let (felt_amount) = SafeCast_uint256_to_felt(amount)
    return felt_transfer(recipient, felt_amount)
end

@external
func felt_transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : felt
) -> (success : felt):
    let (caller) = get_caller_address()

    transfer_internal(caller, recipient, amount, TRUE)

    return (success=TRUE)
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    to : felt, amount : felt
) -> (zero_balance_before : felt):
    alloc_locals

    only_market()

    with_attr error_message("ZToken: cannot mint to the zero address"):
        assert_not_zero(to)
    end

    let (accumulator) = get_accumulator()

    let (scaled_down_amount) = SafeDecimalMath_div(amount, accumulator)
    with_attr error_message("ZToken: invalid mint amount"):
        assert_not_zero(scaled_down_amount)
    end

    let (raw_balance_before) = raw_balances.read(to)
    let (raw_balance_after) = SafeMath_add(raw_balance_before, scaled_down_amount)
    raw_balances.write(to, raw_balance_after)

    let (raw_supply_before) = raw_total_supply.read()
    let (raw_supply_after) = SafeMath_add(raw_supply_before, scaled_down_amount)
    raw_total_supply.write(raw_supply_after)

    let (amount_u256 : Uint256) = SafeCast_felt_to_uint256(amount)
    Transfer.emit(0, to, amount_u256)

    if raw_balance_before == 0:
        return (zero_balance_before=TRUE)
    else:
        return (zero_balance_before=FALSE)
    end
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user : felt, amount : felt
):
    alloc_locals

    only_market()

    let (accumulator) = get_accumulator()

    let (scaled_down_amount) = SafeDecimalMath_div(amount, accumulator)
    with_attr error_message("ZToken: invalid burn amount"):
        assert_not_zero(scaled_down_amount)
    end

    let (raw_balance_before) = raw_balances.read(user)
    let (raw_balance_after) = SafeMath_sub(raw_balance_before, scaled_down_amount)
    raw_balances.write(user, raw_balance_after)

    let (raw_supply_before) = raw_total_supply.read()
    let (raw_supply_after) = SafeMath_sub(raw_supply_before, scaled_down_amount)
    raw_total_supply.write(raw_supply_after)

    let (amount_u256 : Uint256) = SafeCast_felt_to_uint256(amount)
    Transfer.emit(user, 0, amount_u256)

    return ()
end

@external
func move{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    from_account : felt, to_account : felt, amount : felt
):
    only_market()

    # No need to check collateralization as `Market` only moves for liquidation
    return transfer_internal(from_account, to_account, amount, FALSE)
end

func only_market{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (market_addr) = market.read()
    let (caller) = get_caller_address()
    with_attr error_message("ZToken: not market"):
        assert market_addr = caller
    end
    return ()
end

func get_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    accumulator : felt
):
    let (market_addr) = market.read()
    let (underlying_addr) = underlying.read()
    let (accumulator) = IMarket.get_lending_accumulator(
        contract_address=market_addr, token=underlying_addr
    )
    return (accumulator=accumulator)
end

func transfer_internal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    from_account : felt, to_account : felt, amount : felt, check_collateralization : felt
):
    alloc_locals

    let (accumulator) = get_accumulator()

    let (scaled_down_amount) = SafeDecimalMath_div(amount, accumulator)
    with_attr error_message("ZToken: invalid transfer amount"):
        assert_not_zero(scaled_down_amount)
    end

    # No need to check from balance first because SafeMath will fail
    let (raw_from_balance_before) = raw_balances.read(from_account)
    let (raw_from_balance_after) = SafeMath_sub(raw_from_balance_before, scaled_down_amount)
    raw_balances.write(from_account, raw_from_balance_after)

    let (raw_to_balance_before) = raw_balances.read(to_account)
    let (raw_to_balance_after) = SafeMath_add(raw_to_balance_before, scaled_down_amount)
    raw_balances.write(to_account, raw_to_balance_after)

    let (amount_u256 : Uint256) = SafeCast_felt_to_uint256(amount)
    Transfer.emit(from_account, to_account, amount_u256)

    if check_collateralization == TRUE:
        # TODO: skip check if token is not used as collateral
        # TODO: skip check if sender has no debt
        let (market_addr) = market.read()
        let (is_undercollateralized) = IMarket.is_user_undercollateralized(
            contract_address=market_addr, user=from_account
        )

        with_attr error_message("ZToken: invalid collateralization after transfer"):
            assert is_undercollateralized = FALSE
        end

        return ()
    else:
        return ()
    end
end
