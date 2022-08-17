# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.internals.ZToken.events import RawTransfer
from zklend.internals.ZToken.storage import (
    market,
    underlying,
    token_name,
    token_symbol,
    token_decimals,
    raw_total_supply,
    raw_balances,
    allowances,
)

from zklend.interfaces.IMarket import IMarket
from zklend.libraries.SafeCast import SafeCast
from zklend.libraries.SafeDecimalMath import SafeDecimalMath
from zklend.libraries.SafeMath import SafeMath

from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.upgrades.library import Proxy
from openzeppelin.token.erc20.library import Approval, Transfer

namespace External:
    #
    # Upgradeability
    #

    func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        proxy_admin : felt,
        _market : felt,
        _underlying : felt,
        _name : felt,
        _symbol : felt,
        _decimals : felt,
    ):
        Proxy.initializer(proxy_admin)

        with_attr error_message("ZToken: zero address"):
            assert_not_zero(_market)
            assert_not_zero(_underlying)
        end

        market.write(_market)
        underlying.write(_underlying)

        # We probably don't need to range check `_decimals` as it's checked against the real token
        # when adding reserves anyways.
        token_name.write(_name)
        token_symbol.write(_symbol)
        token_decimals.write(_decimals)

        return ()
    end

    func upgrade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_implementation : felt
    ):
        Proxy.assert_only_admin()
        return Proxy._set_implementation_hash(new_implementation)
    end

    func transfer_proxy_admin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_admin : felt
    ):
        Proxy.assert_only_admin()
        return Proxy._set_admin(new_admin)
    end

    #
    # Permissionless entrypoints
    #

    func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256
    ) -> (success : felt):
        let (felt_amount) = SafeCast.uint256_to_felt(amount)
        return felt_transfer(recipient, felt_amount)
    end

    func felt_transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : felt
    ) -> (success : felt):
        let (caller) = get_caller_address()

        # NOTE: this exploit should no longer be possible since all transactions need must go through
        #       the __execute__ method now, but we're still keeping it just in case
        with_attr error_message("ZToken: zero address"):
            assert_not_zero(caller)
        end

        Internal.transfer_internal(
            from_account=caller,
            to_account=recipient,
            amount=amount,
            is_amount_raw=FALSE,
            check_collateralization=TRUE,
        )

        return (success=TRUE)
    end

    func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, recipient : felt, amount : Uint256
    ) -> (success : felt):
        let (felt_amount) = SafeCast.uint256_to_felt(amount)
        return felt_transfer_from(sender, recipient, felt_amount)
    end

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
        let (new_allowance) = SafeMath.sub(existing_allowance, amount)
        allowances.write(sender, caller, new_allowance)

        let (new_allowance_u256) = SafeCast.felt_to_uint256(new_allowance)
        Approval.emit(sender, caller, new_allowance_u256)

        Internal.transfer_internal(
            from_account=sender,
            to_account=recipient,
            amount=amount,
            is_amount_raw=FALSE,
            check_collateralization=TRUE,
        )

        return (success=TRUE)
    end

    func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, amount : Uint256
    ) -> (success : felt):
        let (felt_amount) = SafeCast.uint256_to_felt(amount)
        return felt_approve(spender, felt_amount)
    end

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

        let (amount_u256) = SafeCast.felt_to_uint256(amount)

        Approval.emit(caller, spender, amount_u256)

        return (success=TRUE)
    end

    # This method exists because ZToken balances are always increasing (unless when no interest is
    # accumulating). so it's hard for off-chain actors to clear balance completely.
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
        Internal.transfer_internal(
            from_account=caller,
            to_account=recipient,
            amount=sender_raw_balance,
            is_amount_raw=TRUE,
            check_collateralization=TRUE,
        )

        return ()
    end

    #
    # Permissioned entrypoints
    #

    func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, amount : felt
    ) -> (zero_balance_before : felt):
        alloc_locals

        Internal.only_market()

        with_attr error_message("ZToken: cannot mint to the zero address"):
            assert_not_zero(to)
        end

        let (accumulator) = Internal.get_accumulator()

        let (scaled_down_amount) = SafeDecimalMath.div(amount, accumulator)
        with_attr error_message("ZToken: invalid mint amount"):
            assert_not_zero(scaled_down_amount)
        end

        let (raw_balance_before) = raw_balances.read(to)
        let (raw_balance_after) = SafeMath.add(raw_balance_before, scaled_down_amount)
        raw_balances.write(to, raw_balance_after)

        let (raw_supply_before) = raw_total_supply.read()
        let (raw_supply_after) = SafeMath.add(raw_supply_before, scaled_down_amount)
        raw_total_supply.write(raw_supply_after)

        let (amount_u256 : Uint256) = SafeCast.felt_to_uint256(amount)
        Transfer.emit(0, to, amount_u256)

        if raw_balance_before == 0:
            return (zero_balance_before=TRUE)
        else:
            return (zero_balance_before=FALSE)
        end
    end

    func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user : felt, amount : felt
    ):
        alloc_locals

        Internal.only_market()

        let (accumulator) = Internal.get_accumulator()

        let (scaled_down_amount) = SafeDecimalMath.div(amount, accumulator)
        with_attr error_message("ZToken: invalid burn amount"):
            assert_not_zero(scaled_down_amount)
        end

        let (raw_balance_before) = raw_balances.read(user)
        let (raw_balance_after) = SafeMath.sub(raw_balance_before, scaled_down_amount)
        raw_balances.write(user, raw_balance_after)

        let (raw_supply_before) = raw_total_supply.read()
        let (raw_supply_after) = SafeMath.sub(raw_supply_before, scaled_down_amount)
        raw_total_supply.write(raw_supply_after)

        let (amount_u256 : Uint256) = SafeCast.felt_to_uint256(amount)
        Transfer.emit(user, 0, amount_u256)

        return ()
    end

    func burn_all{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user : felt
    ) -> (amount_burnt : felt):
        alloc_locals

        Internal.only_market()

        let (raw_balance) = raw_balances.read(user)
        with_attr error_message("ZToken: invalid burn amount"):
            assert_not_zero(raw_balance)
        end

        raw_balances.write(user, 0)

        let (raw_supply_before) = raw_total_supply.read()
        let (raw_supply_after) = SafeMath.sub(raw_supply_before, raw_balance)
        raw_total_supply.write(raw_supply_after)

        let (accumulator) = Internal.get_accumulator()
        let (scaled_up_amount) = SafeDecimalMath.mul(raw_balance, accumulator)
        let (scaled_up_amount_u256 : Uint256) = SafeCast.felt_to_uint256(scaled_up_amount)
        Transfer.emit(user, 0, scaled_up_amount_u256)

        return (amount_burnt=scaled_up_amount)
    end

    func move{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        from_account : felt, to_account : felt, amount : felt
    ):
        Internal.only_market()

        # No need to check collateralization as `Market` only moves for liquidation
        return Internal.transfer_internal(
            from_account=from_account,
            to_account=to_account,
            amount=amount,
            is_amount_raw=FALSE,
            check_collateralization=FALSE,
        )
    end
end

namespace View:
    #
    # Getters
    #

    func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
        let (res) = token_name.read()
        return (name=res)
    end

    func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        symbol : felt
    ):
        let (res) = token_symbol.read()
        return (symbol=res)
    end

    func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        decimals : felt
    ):
        let (res) = token_decimals.read()
        return (decimals=res)
    end

    func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        total_supply : Uint256
    ):
        alloc_locals

        let (accumulator) = Internal.get_accumulator()

        let (supply) = raw_total_supply.read()
        let (scaled_up_supply) = SafeDecimalMath.mul(supply, accumulator)
        let (scaled_up_supply_u256 : Uint256) = SafeCast.felt_to_uint256(scaled_up_supply)

        return (total_supply=scaled_up_supply_u256)
    end

    func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt
    ) -> (balance : Uint256):
        let (scaled_up_balance) = felt_balance_of(account)
        let (scaled_up_balance_u256 : Uint256) = SafeCast.felt_to_uint256(scaled_up_balance)

        return (balance=scaled_up_balance_u256)
    end

    func felt_balance_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt
    ) -> (balance : felt):
        alloc_locals

        let (accumulator) = Internal.get_accumulator()

        let (balance) = raw_balances.read(account)
        let (scaled_up_balance) = SafeDecimalMath.mul(balance, accumulator)

        return (balance=scaled_up_balance)
    end

    func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, spender : felt
    ) -> (remaining : Uint256):
        let (remaining) = felt_allowance(owner, spender)
        let (remaining_u256 : Uint256) = SafeCast.felt_to_uint256(remaining)

        return (remaining=remaining_u256)
    end

    func felt_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, spender : felt
    ) -> (remaining : felt):
        let (amount) = allowances.read(owner, spender)
        return (remaining=amount)
    end

    func underlying_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        token : felt
    ):
        let (res) = underlying.read()
        return (token=res)
    end

    func get_raw_total_supply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (raw_supply : felt):
        let (raw_supply) = raw_total_supply.read()
        return (raw_supply=raw_supply)
    end
end

namespace Internal:
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
        from_account : felt,
        to_account : felt,
        amount : felt,
        is_amount_raw : felt,
        check_collateralization : felt,
    ):
        alloc_locals

        let (accumulator) = get_accumulator()

        local raw_amount : felt
        local face_amount : felt
        if is_amount_raw == TRUE:
            let (scaled_up_amount) = SafeDecimalMath.mul(amount, accumulator)
            raw_amount = amount
            face_amount = scaled_up_amount
        else:
            let (scaled_down_amount) = SafeDecimalMath.div(amount, accumulator)
            raw_amount = scaled_down_amount
            face_amount = amount
        end

        with_attr error_message("ZToken: invalid transfer amount"):
            assert_not_zero(raw_amount)
        end

        # No need to check from balance first because SafeMath will fail
        let (raw_from_balance_before) = raw_balances.read(from_account)
        let (raw_from_balance_after) = SafeMath.sub(raw_from_balance_before, raw_amount)
        raw_balances.write(from_account, raw_from_balance_after)

        let (raw_to_balance_before) = raw_balances.read(to_account)
        let (raw_to_balance_after) = SafeMath.add(raw_to_balance_before, raw_amount)
        raw_balances.write(to_account, raw_to_balance_after)

        let (face_amount_u256 : Uint256) = SafeCast.felt_to_uint256(face_amount)
        Transfer.emit(from_account, to_account, face_amount_u256)
        RawTransfer.emit(from_account, to_account, raw_amount, accumulator, face_amount)

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
end
