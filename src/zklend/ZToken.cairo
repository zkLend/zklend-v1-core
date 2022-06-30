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

from openzeppelin.token.erc20.library import Approval, Transfer
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
func token_name() -> (name : felt):
end

@storage_var
func token_symbol() -> (symbol : felt):
end

@storage_var
func token_decimals() -> (decimals : felt):
end

@storage_var
func raw_total_supply() -> (total_supply : felt):
end

@storage_var
func raw_balances(account : felt) -> (balance : felt):
end

@storage_var
func allowances(owner : felt, spender : felt) -> (allowance : felt):
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

    # TODO: check `decimals` range
    token_name.write(_name)
    token_symbol.write(_symbol)
    token_decimals.write(_decimals)

    return ()
end

#
# Getters
#

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (res) = token_name.read()
    return (name=res)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (res) = token_symbol.read()
    return (symbol=res)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    decimals : felt
):
    let (res) = token_decimals.read()
    return (decimals=res)
end

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

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt
) -> (remaining : Uint256):
    let (remaining) = felt_allowance(owner, spender)
    let (remaining_u256 : Uint256) = SafeCast_felt_to_uint256(remaining)

    return (remaining=remaining_u256)
end

@view
func felt_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, spender : felt
) -> (remaining : felt):
    let (amount) = allowances.read(owner, spender)
    return (remaining=amount)
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

    # NOTE: this exploit should no longer be possible since all transactions need must go through
    #       the __execute__ method now, but we're still keeping it just in case
    with_attr error_message("ZToken: zero address"):
        assert_not_zero(caller)
    end

    transfer_internal(caller, recipient, amount, TRUE)

    return (success=TRUE)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender : felt, recipient : felt, amount : Uint256
) -> (success : felt):
    let (felt_amount) = SafeCast_uint256_to_felt(amount)
    return felt_transfer_from(sender, recipient, felt_amount)
end

@external
func felt_transfer_from{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    sender : felt, recipient : felt, amount : felt
) -> (success : felt):
    let (caller) = get_caller_address()

    # NOTE: this exploit should no longer be possible since all transactions need must go through
    #       the __execute__ method now, but we're still keeping it just in case
    with_attr error_message("ZToken: zero address"):
        assert_not_zero(caller)
    end

    # Allowances are not scaled so we can just subtract directly
    let (existing_allowance) = allowances.read(sender, caller)
    let (new_allowance) = SafeMath_sub(existing_allowance, amount)
    allowances.write(sender, caller, new_allowance)

    let (new_allowance_u256) = SafeCast_felt_to_uint256(new_allowance)
    Approval.emit(sender, caller, new_allowance_u256)

    transfer_internal(sender, recipient, amount, TRUE)

    return (success=TRUE)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, amount : Uint256
) -> (success : felt):
    let (felt_amount) = SafeCast_uint256_to_felt(amount)
    return felt_approve(spender, felt_amount)
end

@external
func felt_approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    spender : felt, amount : felt
) -> (success : felt):
    let (caller) = get_caller_address()

    # NOTE: this exploit should no longer be possible since all transactions need must go through
    #       the __execute__ method now, but we're still keeping it just in case
    with_attr error_message("ZToken: zero address"):
        assert_not_zero(caller)
    end

    allowances.write(caller, spender, amount)

    let (amount_u256) = SafeCast_felt_to_uint256(amount)

    Approval.emit(caller, spender, amount_u256)

    return (success=TRUE)
end

# This method exists because ZToken balances are always increasing (unless when no interest is
# accumulating). so it's hard for off-chain actors to clear balance completely.
@external
func transfer_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    recipient : felt
):
    let (caller) = get_caller_address()

    # NOTE: this exploit should no longer be possible since all transactions need must go through
    #       the __execute__ method now, but we're still keeping it just in case
    with_attr error_message("ZToken: zero address"):
        assert_not_zero(caller)
    end

    let (sender_raw_balance) = raw_balances.read(caller)
    transfer_raw_internal(caller, recipient, sender_raw_balance, TRUE)

    return ()
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

func transfer_raw_internal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    from_account : felt, to_account : felt, raw_amount : felt, check_collateralization : felt
):
    alloc_locals

    with_attr error_message("ZToken: invalid transfer amount"):
        assert_not_zero(raw_amount)
    end

    # No need to check from balance first because SafeMath will fail
    let (raw_from_balance_before) = raw_balances.read(from_account)
    let (raw_from_balance_after) = SafeMath_sub(raw_from_balance_before, raw_amount)
    raw_balances.write(from_account, raw_from_balance_after)

    let (raw_to_balance_before) = raw_balances.read(to_account)
    let (raw_to_balance_after) = SafeMath_add(raw_to_balance_before, raw_amount)
    raw_balances.write(to_account, raw_to_balance_after)

    let (accumulator) = get_accumulator()
    let (scaled_up_amount) = SafeDecimalMath_mul(raw_amount, accumulator)

    let (scaled_up_amount_u256 : Uint256) = SafeCast_felt_to_uint256(scaled_up_amount)
    Transfer.emit(from_account, to_account, scaled_up_amount_u256)

    # TODO: refactor duplicate code
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
