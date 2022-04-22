# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.interfaces.IMarket import IMarket
from zklend.libraries.SafeCast import SafeCast_felt_to_uint256
from zklend.libraries.SafeDecimalMath import SafeDecimalMath_div
from zklend.libraries.SafeMath import SafeMath_div, SafeMath_mul

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.token.erc20.library import ERC20_initializer, ERC20_mint

#
# Storage
#

@storage_var
func market() -> (res : felt):
end

@storage_var
func underlying() -> (res : felt):
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
# External
#

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    to : felt, amount : felt
):
    alloc_locals

    only_market()

    let (market_addr) = market.read()
    let (underlying_addr) = underlying.read()
    let (local accumulator) = IMarket.get_reserve_accumulator(
        contract_address=market_addr, token=underlying_addr
    )

    let (scaled_down_amount) = SafeDecimalMath_div(amount, accumulator)
    let (scaled_amount_u256) = SafeCast_felt_to_uint256(scaled_down_amount)
    ERC20_mint(to, scaled_amount_u256)
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
