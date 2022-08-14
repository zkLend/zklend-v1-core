# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.internals.ZToken.functions import External, View

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.uint256 import Uint256

#
# Upgradeability
#

@external
func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    proxy_admin : felt,
    _market : felt,
    _underlying : felt,
    _name : felt,
    _symbol : felt,
    _decimals : felt,
):
    return External.initializer(proxy_admin, _market, _underlying, _name, _symbol, _decimals)
end

@external
func upgrade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_implementation : felt
):
    return External.upgrade(new_implementation)
end

@external
func transfer_proxy_admin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_admin : felt
):
    return External.transfer_proxy_admin(new_admin)
end

#
# Getters
#

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    return View.name()
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    return View.symbol()
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    decimals : felt
):
    return View.decimals()
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    total_supply : Uint256
):
    return View.totalSupply()
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (balance : Uint256):
    return View.balanceOf(account)
end

@view
func felt_balance_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    account : felt
) -> (balance : felt):
    return View.felt_balance_of(account)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt
) -> (remaining : Uint256):
    return View.allowance(owner, spender)
end

@view
func felt_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt
) -> (remaining : felt):
    return View.felt_allowance(owner, spender)
end

@view
func underlying_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    token : felt
):
    return View.underlying_token()
end

@view
func get_raw_total_supply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    raw_supply : felt
):
    return View.get_raw_total_supply()
end

#
# Permissionless entrypoints
#

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : Uint256
) -> (success : felt):
    return External.transfer(recipient, amount)
end

@external
func felt_transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt, amount : felt
) -> (success : felt):
    return External.felt_transfer(recipient, amount)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender : felt, recipient : felt, amount : Uint256
) -> (success : felt):
    return External.transferFrom(sender, recipient, amount)
end

@external
func felt_transfer_from{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender : felt, recipient : felt, amount : felt
) -> (success : felt):
    return External.felt_transfer_from(sender, recipient, amount)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, amount : Uint256
) -> (success : felt):
    return External.approve(spender, amount)
end

@external
func felt_approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, amount : felt
) -> (success : felt):
    return External.felt_approve(spender, amount)
end

# This method exists because ZToken balances are always increasing (unless when no interest is
# accumulating). so it's hard for off-chain actors to clear balance completely.
@external
func transfer_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt
):
    return External.transfer_all(recipient)
end

#
# Permissioned entrypoints
#

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    to : felt, amount : felt
) -> (zero_balance_before : felt):
    return External.mint(to, amount)
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    user : felt, amount : felt
):
    return External.burn(user, amount)
end

@external
func burn_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(user : felt) -> (
    amount_burnt : felt
):
    return External.burn_all(user)
end

@external
func move{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    from_account : felt, to_account : felt, amount : felt
):
    return External.move(from_account, to_account, amount)
end
