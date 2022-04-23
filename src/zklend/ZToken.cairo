# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.interfaces.IMarket import IMarket
from zklend.libraries.SafeCast import SafeCast_felt_to_uint256
from zklend.libraries.SafeDecimalMath import SafeDecimalMath_div, SafeDecimalMath_mul
from zklend.libraries.SafeMath import SafeMath_add, SafeMath_div, SafeMath_mul, SafeMath_sub

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.token.erc20.library import ERC20_initializer, Transfer

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
    alloc_locals

    let (accumulator) = get_accumulator()

    let (balance) = raw_balances.read(account)
    let (scaled_up_balance) = SafeDecimalMath_mul(balance, accumulator)
    let (scaled_up_balance_u256 : Uint256) = SafeCast_felt_to_uint256(scaled_up_balance)

    return (balance=scaled_up_balance_u256)
end

#
# External
#

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    to : felt, amount : felt
):
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

    return ()
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
    let (accumulator) = IMarket.get_reserve_accumulator(
        contract_address=market_addr, token=underlying_addr
    )
    return (accumulator=accumulator)
end
