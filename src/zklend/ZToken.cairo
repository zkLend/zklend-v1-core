# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.token.erc20.library import ERC20_initializer, ERC20_mint

#
# Storage
#

@storage_var
func market() -> (res : felt):
end

#
# Constructor
#
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    _market : felt, _name : felt, _symbol : felt, _decimals : felt
):
    market.write(_market)
    ERC20_initializer(_name, _symbol, _decimals)
    return ()
end

#
# External
#

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    to : felt, amount : Uint256
):
    only_market()
    ERC20_mint(to, amount)
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
