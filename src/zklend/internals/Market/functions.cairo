# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.internals.Market.events import (
    NewReserve,
    TreasuryUpdate,
    AccumulatorsSync,
    InterestRatesSync,
    ReserveFactorUpdate,
    LiquidationBonusUpdate,
    Deposit,
    Withdrawal,
    Borrowing,
    Repayment,
    Liquidation,
    FlashLoan,
    CollateralEnabled,
    CollateralDisabled,
)
from zklend.internals.Market.storage import (
    oracle,
    treasury,
    reserves,
    reserve_count,
    reserve_tokens,
    reserve_indices,
    user_flags,
    raw_user_debts,
)
from zklend.internals.Market.structs import Structs

from zklend.interfaces.callback.IZklendFlashCallback import IZklendFlashCallback
from zklend.interfaces.IInterestRateModel import IInterestRateModel
from zklend.interfaces.IPriceOracle import IPriceOracle
from zklend.interfaces.IZToken import IZToken
from zklend.libraries.Math import Math
from zklend.libraries.SafeCast import SafeCast
from zklend.libraries.SafeDecimalMath import SafeDecimalMath, SCALE
from zklend.libraries.SafeMath import SafeMath

from starkware.cairo.common.bitwise import bitwise_and, bitwise_not, bitwise_or
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

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.security.reentrancyguard.library import ReentrancyGuard
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.upgrades.library import Proxy, Proxy_initialized

const SECONDS_PER_YEAR = 31536000

# 0b1010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
const DEBT_FLAG_FILTER = 1206167596222043702328864427173832373471562340267089208744349833415761767082

# This namespace is mostly used for adding reentrancy guard
namespace External:
    #
    # Upgradeability
    #

    func initializer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, _oracle : felt
    ):
        let (initialized) = Proxy_initialized.read()
        with_attr error_message("Proxy: contract already initialized"):
            assert initialized = FALSE
        end
        Proxy_initialized.write(TRUE)

        with_attr error_message("Market: zero address"):
            assert_not_zero(owner)
            assert_not_zero(_oracle)
        end

        Ownable.initializer(owner)
        oracle.write(_oracle)

        return ()
    end

    func upgrade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_implementation : felt
    ):
        Ownable.assert_only_owner()
        return Proxy._set_implementation_hash(new_implementation)
    end

    #
    # Permissionless entrypoints
    #

    func deposit{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt, amount : felt):
        ReentrancyGuard._start()
        Internal.deposit(token, amount)
        ReentrancyGuard._end()
        return ()
    end

    func withdraw{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt, amount : felt):
        ReentrancyGuard._start()
        Internal.withdraw(token, amount)
        ReentrancyGuard._end()
        return ()
    end

    func withdraw_all{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt):
        ReentrancyGuard._start()
        Internal.withdraw_all(token)
        ReentrancyGuard._end()
        return ()
    end

    func borrow{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt, amount : felt):
        ReentrancyGuard._start()
        Internal.borrow(token, amount)
        ReentrancyGuard._end()
        return ()
    end

    func repay{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt, amount : felt):
        ReentrancyGuard._start()
        Internal.repay(token, amount)
        ReentrancyGuard._end()
        return ()
    end

    func repay_all{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt):
        ReentrancyGuard._start()
        Internal.repay_all(token)
        ReentrancyGuard._end()
        return ()
    end

    func enable_collateral{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt):
        ReentrancyGuard._start()
        Internal.enable_collateral(token)
        ReentrancyGuard._end()
        return ()
    end

    func disable_collateral{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt):
        ReentrancyGuard._start()
        Internal.disable_collateral(token)
        ReentrancyGuard._end()
        return ()
    end

    # With the current design, liquidators are responsible for calculating the maximum amount allowed.
    # We simply check collteralization factor is below one after liquidation.
    # TODO: calculate max amount on-chain because compute is cheap on StarkNet.
    func liquidate{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, debt_token : felt, amount : felt, collateral_token : felt):
        ReentrancyGuard._start()
        Internal.liquidate(user, debt_token, amount, collateral_token)
        ReentrancyGuard._end()
        return ()
    end

    func flash_loan{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        receiver : felt, token : felt, amount : felt, calldata_len : felt, calldata : felt*
    ):
        ReentrancyGuard._start()
        Internal.flash_loan(receiver, token, amount, calldata_len, calldata)
        ReentrancyGuard._end()
        return ()
    end

    #
    # Permissioned entrypoints
    #

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

        let (existing_reserve_z_token) = reserves.read_z_token_address(token)
        with_attr error_message("Market: reserve already exists"):
            assert existing_reserve_z_token = 0
        end

        # Checks collateral_factor range
        with_attr error_message("Market: collteral factor out of range"):
            assert_le_felt(collateral_factor, SCALE)
        end

        # Checks borrow_factor range
        with_attr error_message("Market: borrow factor out of range"):
            assert_le_felt(borrow_factor, SCALE)
        end

        # Checks reserve_factor range
        with_attr error_message("Market: reserve factor out of range"):
            assert_le_felt(reserve_factor, SCALE)
        end

        # There's no need to limit `flash_loan_fee` range as it's charged on top of the loan amount

        let (decimals) = IERC20.decimals(contract_address=token)
        let (z_token_decimals) = IERC20.decimals(contract_address=z_token)
        with_attr error_message("Market: token decimals mismatch"):
            assert decimals = z_token_decimals
        end

        # Checks underlying token of the Z token contract
        let (z_token_underlying) = IZToken.underlying_token(contract_address=z_token)
        with_attr error_message("Market: underlying token mismatch"):
            assert z_token_underlying = token
        end

        #
        # Effects
        #
        let new_reserve = Structs.ReserveData(
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
            flash_loan_fee=flash_loan_fee,
            liquidation_bonus=liquidation_bonus,
        )
        reserves.write(token, new_reserve)

        NewReserve.emit(
            token,
            z_token,
            decimals,
            interest_rate_model,
            collateral_factor,
            borrow_factor,
            reserve_factor,
            flash_loan_fee,
            liquidation_bonus,
        )

        AccumulatorsSync.emit(token, SCALE, SCALE)
        InterestRatesSync.emit(token, 0, 0)

        let (current_reserve_count) = reserve_count.read()
        let new_reserve_count = current_reserve_count + 1
        reserve_count.write(new_reserve_count)
        reserve_tokens.write(current_reserve_count, token)
        reserve_indices.write(token, current_reserve_count)

        # We can only have up to 125 reserves due to the use of bitmap for user collateral usage
        # and debt flags until we will change to use more than 1 felt for that.
        with_attr error_message("Market: too many reserves"):
            assert_le_felt(new_reserve_count, 125)
        end

        return ()
    end

    func set_reserve_factor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token : felt, new_reserve_factor : felt
    ):
        alloc_locals

        Ownable.assert_only_owner()

        # Checks reserve_factor range
        with_attr error_message("Market: reserve factor out of range"):
            assert_le_felt(new_reserve_factor, SCALE)
        end

        # We must update accumulators first, otherwise bad things might happen (e.g. user collateral
        # balance decreases)
        let (_, updated_debt_accumulator) = Internal.update_accumulators(token)

        # Looks like it isn't necessary to also update rates here but still doing it just to be safe
        Internal.update_rates_and_raw_total_debt(
            token=token,
            updated_debt_accumulator=updated_debt_accumulator,
            is_delta_reserve_balance_negative=FALSE,
            abs_delta_reserve_balance=0,
            is_delta_raw_total_debt_negative=FALSE,
            abs_delta_raw_total_debt=0,
        )

        reserves.write_reserve_factor(token, new_reserve_factor)

        ReserveFactorUpdate.emit(token, new_reserve_factor)

        return ()
    end

    func set_liquidation_bonus{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token : felt, new_liquidation_bonus : felt
    ):
        alloc_locals

        Ownable.assert_only_owner()

        # No need to update accumulators or rates

        Internal.assert_reserve_exists(token)

        reserves.write_liquidation_bonus(token, new_liquidation_bonus)

        LiquidationBonusUpdate.emit(token, new_liquidation_bonus)

        return ()
    end

    func set_treasury{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_treasury : felt
    ):
        Ownable.assert_only_owner()

        treasury.write(new_treasury)
        TreasuryUpdate.emit(new_treasury)
        return ()
    end

    func transfer_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_owner : felt
    ):
        return Ownable.transfer_ownership(new_owner)
    end

    func renounce_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
        return Ownable.renounce_ownership()
    end
end

namespace View:
    #
    # Getters
    #

    func get_reserve_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token : felt
    ) -> (data : Structs.ReserveData):
        let (reserve) = reserves.read(token)
        return (data=reserve)
    end

    func get_lending_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token : felt
    ) -> (res : felt):
        alloc_locals

        Internal.assert_reserve_enabled(token)
        let reserve = reserves.read_for_get_lending_accumulator(token)

        let (block_timestamp) = get_block_timestamp()
        if reserve.last_update_timestamp == block_timestamp:
            # Accumulator already updated on the same block
            return (res=reserve.lending_accumulator)
        else:
            # Apply simple interest
            let (time_diff) = SafeMath.sub(block_timestamp, reserve.last_update_timestamp)

            # Treats reserve factor as zero if treasury address is not set
            let (treasury_addr) = treasury.read()
            local effective_reserve_factor : felt
            if treasury_addr == 0:
                effective_reserve_factor = 0
            else:
                effective_reserve_factor = reserve.reserve_factor
            end

            let (one_minus_reserve_factor) = SafeMath.sub(SCALE, effective_reserve_factor)

            # New accumulator
            # (current_lending_rate * (1 - reserve_factor) * time_diff / SECONDS_PER_YEAR + 1) * accumulator
            let (temp_1) = SafeMath.mul(reserve.current_lending_rate, time_diff)
            let (temp_2) = SafeMath.mul(temp_1, one_minus_reserve_factor)
            let (temp_3) = SafeMath.div(temp_2, SECONDS_PER_YEAR)
            let (temp_4) = SafeMath.div(temp_3, SCALE)
            let (temp_5) = SafeMath.add(temp_4, SCALE)
            let (latest_accumulator) = SafeDecimalMath.mul(temp_5, reserve.lending_accumulator)

            return (res=latest_accumulator)
        end
    end

    func get_debt_accumulator{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token : felt
    ) -> (res : felt):
        alloc_locals

        Internal.assert_reserve_enabled(token)
        let reserve = reserves.read_for_get_debt_accumulator(token)

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

    # WARN: this must be run BEFORE adjusting the accumulators (otherwise always returns 0)
    func get_pending_treasury_amount{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(token : felt) -> (res : felt):
        alloc_locals

        Internal.assert_reserve_enabled(token)
        let reserve = reserves.read_for_get_pending_treasury_amount(token)

        # Nothing for treasury if address set to zero
        let (treasury_addr) = treasury.read()
        if treasury_addr == 0:
            return (res=0)
        end

        let (block_timestamp) = get_block_timestamp()
        if reserve.last_update_timestamp == block_timestamp:
            # Tresury amount already settled on the same block
            return (res=0)
        else:
            # Apply simple interest
            let (time_diff) = SafeMath.sub(block_timestamp, reserve.last_update_timestamp)

            let (raw_supply) = IZToken.get_raw_total_supply(
                contract_address=reserve.z_token_address
            )

            # Amount to be paid to treasury (based on the adjusted accumulator)
            # (current_lending_rate * reserve_factor * time_diff / SECONDS_PER_YEAR) * accumulator * raw_supply
            let (temp_1) = SafeMath.mul(reserve.current_lending_rate, time_diff)
            let (temp_2) = SafeMath.mul(temp_1, reserve.reserve_factor)
            let (temp_3) = SafeMath.div(temp_2, SECONDS_PER_YEAR)
            let (temp_4) = SafeMath.div(temp_3, SCALE)
            let (temp_5) = SafeDecimalMath.mul(temp_4, reserve.lending_accumulator)
            let (amount_to_treasury) = SafeDecimalMath.mul(raw_supply, temp_5)

            return (res=amount_to_treasury)
        end
    end

    func get_total_debt_for_token{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(token : felt) -> (debt : felt):
        alloc_locals

        Internal.assert_reserve_enabled(token)
        let (raw_total_debt) = reserves.read_raw_total_debt(token)

        let (debt_accumulator) = get_debt_accumulator(token)
        let (scaled_up_debt) = SafeDecimalMath.mul(raw_total_debt, debt_accumulator)
        return (debt=scaled_up_debt)
    end

    func get_user_debt_for_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user : felt, token : felt
    ) -> (debt : felt):
        alloc_locals

        let (debt_accumulator) = get_debt_accumulator(token)
        let (raw_debt) = raw_user_debts.read(user, token)

        let (scaled_up_debt) = SafeDecimalMath.mul(raw_debt, debt_accumulator)
        return (debt=scaled_up_debt)
    end

    func get_user_flags{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user : felt
    ) -> (map : felt):
        let (map) = user_flags.read(user)
        return (map=map)
    end

    func is_user_undercollateralized{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, apply_borrow_factor : felt) -> (is_undercollateralized : felt):
        let (user_not_undercollateralized) = Internal.is_not_undercollateralized(
            user, apply_borrow_factor
        )

        if user_not_undercollateralized == TRUE:
            return (is_undercollateralized=FALSE)
        else:
            return (is_undercollateralized=TRUE)
        end
    end

    func is_collateral_enabled{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, token : felt) -> (enabled : felt):
        let (enabled) = Internal.is_used_as_collateral(user, token)
        return (enabled=enabled)
    end

    func user_has_debt{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt) -> (has_debt : felt):
        return Internal.user_has_debt(user)
    end
end

namespace Internal:
    #
    # External-to-be-wrapped
    #

    func deposit{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt, amount : felt):
        alloc_locals

        let (caller) = get_caller_address()
        let (this_address) = get_contract_address()

        let (_, updated_debt_accumulator) = update_accumulators(token)

        #
        # Checks
        #
        Internal.assert_reserve_enabled(token)
        let (z_token_address) = reserves.read_z_token_address(token)

        #
        # Interactions
        #

        # Updates interest rate
        Internal.update_rates_and_raw_total_debt(
            token=token,
            updated_debt_accumulator=updated_debt_accumulator,
            is_delta_reserve_balance_negative=FALSE,
            abs_delta_reserve_balance=amount,
            is_delta_raw_total_debt_negative=FALSE,
            abs_delta_raw_total_debt=0,
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
        IZToken.mint(contract_address=z_token_address, to=caller, amount=amount)

        return ()
    end

    func withdraw{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt, amount : felt):
        with_attr error_message("Market: zero amount"):
            assert_not_zero(amount)
        end

        let (caller) = get_caller_address()
        return withdraw_internal(caller, token, amount)
    end

    func withdraw_all{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt):
        let (caller) = get_caller_address()
        return withdraw_internal(caller, token, 0)
    end

    func borrow{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt, amount : felt):
        alloc_locals

        let (caller) = get_caller_address()

        let (_, updated_debt_accumulator) = update_accumulators(token)

        Internal.assert_reserve_enabled(token)

        let (scaled_down_amount) = SafeDecimalMath.div(amount, updated_debt_accumulator)
        with_attr error_message("Market: invalid amount"):
            assert_not_zero(scaled_down_amount)
        end

        # Updates user debt data
        let (raw_user_debt_before) = raw_user_debts.read(caller, token)
        let (raw_user_debt_after) = SafeMath.add(raw_user_debt_before, scaled_down_amount)
        raw_user_debts.write(caller, token, raw_user_debt_after)

        set_user_has_debt(caller, token, raw_user_debt_before, raw_user_debt_after)

        # Updates interest rate
        Internal.update_rates_and_raw_total_debt(
            token=token,
            updated_debt_accumulator=updated_debt_accumulator,
            is_delta_reserve_balance_negative=TRUE,
            abs_delta_reserve_balance=amount,
            is_delta_raw_total_debt_negative=FALSE,
            abs_delta_raw_total_debt=scaled_down_amount,
        )

        Borrowing.emit(caller, token, scaled_down_amount, amount)

        # It's easier to post-check collateralization factor
        with_attr error_message("Market: insufficient collateral"):
            assert_not_undercollateralized(caller, TRUE)
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

    func repay{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt, amount : felt):
        alloc_locals

        with_attr error_message("Market: zero amount"):
            assert_not_zero(amount)
        end

        let (caller) = get_caller_address()

        let (raw_amount, face_amount) = repay_debt_route_internal(caller, caller, token, amount)
        Repayment.emit(caller, token, raw_amount, face_amount)

        return ()
    end

    func repay_all{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt):
        alloc_locals

        let (caller) = get_caller_address()

        let (raw_amount, face_amount) = repay_debt_route_internal(caller, caller, token, 0)
        Repayment.emit(caller, token, raw_amount, face_amount)

        return ()
    end

    func enable_collateral{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt):
        alloc_locals

        let (caller) = get_caller_address()

        Internal.assert_reserve_exists(token)

        set_collateral_usage(caller, token, TRUE)

        CollateralEnabled.emit(caller, token)

        return ()
    end

    func disable_collateral{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(token : felt):
        alloc_locals

        let (caller) = get_caller_address()

        Internal.assert_reserve_exists(token)

        set_collateral_usage(caller, token, FALSE)

        # It's easier to post-check collateralization factor
        with_attr error_message("Market: insufficient collateral"):
            assert_not_undercollateralized(caller, TRUE)
        end

        CollateralDisabled.emit(caller, token)

        return ()
    end

    func liquidate{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, debt_token : felt, amount : felt, collateral_token : felt):
        alloc_locals

        let (caller) = get_caller_address()

        # Validates input
        with_attr error_message("Market: zero amount"):
            assert_not_zero(amount)
        end

        Internal.assert_reserve_enabled(debt_token)
        Internal.assert_reserve_enabled(collateral_token)
        let (debt_reserve_decimals) = reserves.read_decimals(debt_token)
        let (collateral_reserve) = reserves.read(collateral_token)

        # Liquidator repays debt for user
        repay_debt_route_internal(caller, user, debt_token, amount)

        # Can only take from assets being used as collateral
        let (is_collateral) = is_used_as_collateral(user, collateral_token)
        with_attr error_message("Market: cannot withdraw non-collateral token"):
            assert is_collateral = TRUE
        end

        # Liquidator withdraws collateral from user
        let (oracle_addr) = oracle.read()
        let (debt_token_price) = IPriceOracle.get_price(
            contract_address=oracle_addr, token=debt_token
        )
        let (collateral_token_price) = IPriceOracle.get_price(
            contract_address=oracle_addr, token=collateral_token
        )
        let (debt_value_repaid) = SafeDecimalMath.mul_decimals(
            debt_token_price, amount, debt_reserve_decimals
        )
        let (equivalent_collateral_amount) = SafeDecimalMath.div_decimals(
            debt_value_repaid, collateral_token_price, collateral_reserve.decimals
        )
        let (one_plus_liquidation_bonus) = SafeMath.add(SCALE, collateral_reserve.liquidation_bonus)
        let (collateral_amount_after_bonus) = SafeDecimalMath.mul(
            equivalent_collateral_amount, one_plus_liquidation_bonus
        )

        IZToken.move(
            contract_address=collateral_reserve.z_token_address,
            from_account=user,
            to_account=caller,
            amount=collateral_amount_after_bonus,
        )

        # Checks user collateralization factor after liquidation
        with_attr error_message("Market: invalid liquidation"):
            assert_not_overcollateralized(user, FALSE)
        end

        Liquidation.emit(
            caller, user, debt_token, amount, collateral_token, collateral_amount_after_bonus
        )

        return ()
    end

    func flash_loan{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        receiver : felt, token : felt, amount : felt, calldata_len : felt, calldata : felt*
    ):
        alloc_locals

        let (this_address) = get_contract_address()

        # Validates input
        with_attr error_message("Market: zero amount"):
            assert_not_zero(amount)
        end

        Internal.assert_reserve_enabled(token)
        let (flash_loan_fee) = reserves.read_flash_loan_fee(token)

        # Calculates minimum balance after the callback
        let (loan_fee) = SafeDecimalMath.mul(amount, flash_loan_fee)
        let (reserve_balance_before_u256) = IERC20.balanceOf(
            contract_address=token, account=this_address
        )
        let (reserve_balance_before) = SafeCast.uint256_to_felt(reserve_balance_before_u256)
        let (min_balance) = SafeMath.add(reserve_balance_before, loan_fee)

        # Sends funds to receiver
        let (amount_u256) = SafeCast.felt_to_uint256(amount)
        let (transfer_success) = IERC20.transfer(
            contract_address=token, recipient=receiver, amount=amount_u256
        )
        with_attr error_message("Market: transfer failed"):
            assert_not_zero(transfer_success)
        end

        # Calls receiver callback (which should return funds to this contract)
        IZklendFlashCallback.zklend_flash_callback(
            contract_address=receiver, calldata_len=calldata_len, calldata=calldata
        )

        # Checks if enough funds have been returned
        let (reserve_balance_after_u256) = IERC20.balanceOf(
            contract_address=token, account=this_address
        )
        let (reserve_balance_after) = SafeCast.uint256_to_felt(reserve_balance_after_u256)
        with_attr error_message("Market: insufficient amount repaid"):
            assert_le_felt(min_balance, reserve_balance_after)
        end

        # Updates accumulators
        let (_, updated_debt_accumulator) = update_accumulators(token)

        # Updates rates
        Internal.update_rates_and_raw_total_debt(
            token=token,
            updated_debt_accumulator=updated_debt_accumulator,
            is_delta_reserve_balance_negative=FALSE,
            abs_delta_reserve_balance=0,
            is_delta_raw_total_debt_negative=FALSE,
            abs_delta_raw_total_debt=0,
        )

        let (actual_fee) = SafeMath.sub(reserve_balance_after, reserve_balance_before)
        FlashLoan.emit(receiver, token, amount, actual_fee)

        return ()
    end

    #
    # Internal
    #

    # ASSUMPTION: `token` maps to a valid reserve
    func set_collateral_usage{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, token : felt, use : felt):
        let (reserve_index) = reserve_indices.read(token)
        return set_user_flag(user, reserve_index * 2, use)
    end

    # ASSUMPTION: `token` maps to a valid reserve
    func set_user_has_debt{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, token : felt, debt_before : felt, debt_after):
        let (reserve_index) = reserve_indices.read(token)
        if debt_before == 0 and debt_after != 0:
            return set_user_flag(user, reserve_index * 2 + 1, TRUE)
        end
        if debt_before != 0 and debt_after == 0:
            return set_user_flag(user, reserve_index * 2 + 1, FALSE)
        end
        return ()
    end

    func set_user_flag{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, offset : felt, set : felt):
        alloc_locals

        let (reserve_slot) = Math.shl(1, offset)
        let (existing_map) = user_flags.read(user)

        if set == TRUE:
            let (new_map) = bitwise_or(existing_map, reserve_slot)
        else:
            let (inverse_slot) = bitwise_not(reserve_slot)
            let (new_map) = bitwise_and(existing_map, inverse_slot)
        end

        user_flags.write(user, new_map)
        return ()
    end

    # ASSUMPTION: `token` maps to a valid reserve
    func is_used_as_collateral{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, token : felt) -> (is_used : felt):
        alloc_locals

        let (reserve_index) = reserve_indices.read(token)
        let (reserve_slot) = Math.shl(1, reserve_index * 2)
        let (existing_map) = user_flags.read(user)

        let (and_result) = bitwise_and(existing_map, reserve_slot)
        let (is_used) = is_not_zero(and_result)

        return (is_used=is_used)
    end

    func user_has_debt{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt) -> (has_debt : felt):
        let (map) = user_flags.read(user)

        let (and_result) = bitwise_and(map, DEBT_FLAG_FILTER)
        let (has_debt) = is_not_zero(and_result)

        return (has_debt=has_debt)
    end

    func assert_not_overcollateralized{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, apply_borrow_factor : felt):
        let (user_overcollateralized) = is_overcollateralized(user, apply_borrow_factor)
        assert user_overcollateralized = FALSE
        return ()
    end

    func assert_not_undercollateralized{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, apply_borrow_factor : felt):
        let (user_not_undercollateralized) = is_not_undercollateralized(user, apply_borrow_factor)
        assert user_not_undercollateralized = TRUE
        return ()
    end

    func is_not_undercollateralized{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, apply_borrow_factor : felt) -> (res : felt):
        alloc_locals

        # Skips expensive collateralization check if user has no debt at all
        let (has_debt) = user_has_debt(user)
        if has_debt == FALSE:
            return (res=TRUE)
        end

        let (collateral_value, collateral_required) = calculate_user_collateral_data(
            user, apply_borrow_factor
        )
        let (is_not_undercollateralized) = is_le_felt(collateral_required, collateral_value)
        return (res=is_not_undercollateralized)
    end

    # Same as `is_not_undercollateralized` but returns FALSE if equal. Only used in liquidations.
    func is_overcollateralized{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, apply_borrow_factor : felt) -> (res : felt):
        alloc_locals

        # Not using the skip-if-no-debt optimization here because in liquidations the user always
        # has debt left. Checking for debt flags is thus wasteful.

        let (collateral_value, collateral_required) = calculate_user_collateral_data(
            user, apply_borrow_factor
        )

        if collateral_value != collateral_required:
            # Using `le` is fine since we already checked for equalness
            let (is_overcollateralized) = is_le_felt(collateral_required, collateral_value)
            return (res=is_overcollateralized)
        else:
            return (res=FALSE)
        end
    end

    func calculate_user_collateral_data{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, apply_borrow_factor : felt) -> (
        collateral_value : felt, collateral_required : felt
    ):
        let (reserve_cnt) = reserve_count.read()
        if reserve_cnt == 0:
            return (collateral_value=0, collateral_required=0)
        else:
            let (flags) = user_flags.read(user)

            let (collateral_value, collateral_required) = calculate_user_collateral_data_loop(
                user, apply_borrow_factor, flags, reserve_cnt, 0
            )

            return (collateral_value=collateral_value, collateral_required=collateral_required)
        end
    end

    # ASSUMPTION: `reserve_count` is not zero
    func calculate_user_collateral_data_loop{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(
        user : felt,
        apply_borrow_factor : felt,
        flags : felt,
        reserve_count : felt,
        reserve_index : felt,
    ) -> (collateral_value : felt, collateral_required : felt):
        alloc_locals

        if reserve_index == reserve_count:
            return (collateral_value=0, collateral_required=0)
        end

        let (
            collateral_value_of_rest, collateral_required_of_rest
        ) = calculate_user_collateral_data_loop(
            user, apply_borrow_factor, flags, reserve_count, reserve_index + 1
        )
        local collateral_value_of_rest = collateral_value_of_rest
        local collateral_required_of_rest = collateral_required_of_rest

        let (reserve_slot) = Math.shl(1, reserve_index * 2)
        let (reserve_slot_and) = bitwise_and(flags, reserve_slot)

        let (reserve_token) = reserve_tokens.read(reserve_index)

        let (current_collteral_required) = get_collateral_usd_value_required_for_token(
            user, reserve_token, apply_borrow_factor
        )
        let (total_collateral_required) = SafeMath.add(
            current_collteral_required, collateral_required_of_rest
        )

        if reserve_slot_and == FALSE:
            # Reserve not used as collateral
            return (
                collateral_value=collateral_value_of_rest,
                collateral_required=total_collateral_required,
            )
        else:
            let (discounted_collteral_value) = get_user_collateral_usd_value_for_token(
                user, reserve_token
            )
            let (total_collateral_value) = SafeMath.add(
                discounted_collteral_value, collateral_value_of_rest
            )

            return (
                collateral_value=total_collateral_value,
                collateral_required=total_collateral_required,
            )
        end
    end

    # ASSUMPTION: `token` is a valid reserve
    func get_collateral_usd_value_required_for_token{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(user : felt, token : felt, apply_borrow_factor : felt) -> (value : felt):
        alloc_locals

        let (debt_value) = get_user_debt_usd_value_for_token(user, token)
        if apply_borrow_factor == TRUE:
            let (borrow_factor) = reserves.read_borrow_factor(token)
            let (collateral_required) = SafeDecimalMath.div(debt_value, borrow_factor)
            return (value=collateral_required)
        else:
            return (value=debt_value)
        end
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

        let (debt_accumulator) = View.get_debt_accumulator(token)
        let (scaled_up_debt_balance) = SafeDecimalMath.mul(raw_debt_balance, debt_accumulator)

        # Fetches price from oracle
        let (oracle_addr) = oracle.read()
        let (debt_price) = IPriceOracle.get_price(contract_address=oracle_addr, token=token)

        let (decimals) = reserves.read_decimals(token)

        let (debt_value) = SafeDecimalMath.mul_decimals(
            debt_price, scaled_up_debt_balance, decimals
        )

        return (value=debt_value)
    end

    # ASSUMPTION: `token` is a valid reserve
    # ASSUMPTION: `token` is used by `user` as collateral
    func get_user_collateral_usd_value_for_token{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(user : felt, token : felt) -> (value : felt):
        alloc_locals

        let reserve = reserves.read_for_get_user_collateral_usd_value_for_token(token)

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
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(user : felt, token : felt, amount : felt):
        alloc_locals

        let (_, updated_debt_accumulator) = update_accumulators(token)

        #
        # Checks
        #

        Internal.assert_reserve_enabled(token)
        let (z_token_address) = reserves.read_z_token_address(token)

        #
        # Effects
        #

        # NOTE: it's fine to call out to external contract here before state update since it's trusted
        let (amount_burnt) = burn_z_token_internal(z_token_address, user, amount)

        # Updates interest rate
        Internal.update_rates_and_raw_total_debt(
            token=token,
            updated_debt_accumulator=updated_debt_accumulator,
            is_delta_reserve_balance_negative=TRUE,
            abs_delta_reserve_balance=amount_burnt,
            is_delta_raw_total_debt_negative=FALSE,
            abs_delta_raw_total_debt=0,
        )

        Withdrawal.emit(user, token, amount_burnt)

        #
        # Interactions
        #

        # Gives underlying tokens to user
        let (amount_burnt_u256 : Uint256) = SafeCast.felt_to_uint256(amount_burnt)
        let (transfer_success) = IERC20.transfer(
            contract_address=token, recipient=user, amount=amount_burnt_u256
        )
        with_attr error_message("Market: transfer failed"):
            assert_not_zero(transfer_success)
        end

        # It's easier to post-check collateralization factor, at the cost of making failed
        # transactions more expensive.
        let (is_asset_used_as_collateral) = is_used_as_collateral(user, token)
        if is_asset_used_as_collateral == TRUE:
            with_attr error_message("Market: insufficient collateral"):
                assert_not_undercollateralized(user, TRUE)
            end
        else:
            # No need to check if the asset is not used as collateral at all
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
            tempvar bitwise_ptr = bitwise_ptr
        end

        return ()
    end

    # `amount` with `0` means repaying all
    func repay_debt_route_internal{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(repayer : felt, beneficiary : felt, token : felt, amount : felt) -> (
        raw_amount : felt, face_amount : felt
    ):
        alloc_locals

        Internal.assert_reserve_enabled(token)

        let (updated_debt_accumulator) = View.get_debt_accumulator(token)

        if amount == 0:
            let (user_raw_debt) = raw_user_debts.read(beneficiary, token)
            with_attr error_message("Market: no debt to repay"):
                assert_not_zero(user_raw_debt)
            end

            let (repay_amount) = SafeDecimalMath.mul(user_raw_debt, updated_debt_accumulator)

            repay_debt_internal(repayer, beneficiary, token, repay_amount, user_raw_debt)

            return (raw_amount=user_raw_debt, face_amount=repay_amount)
        else:
            let (raw_amount) = SafeDecimalMath.div(amount, updated_debt_accumulator)
            with_attr error_message("Market: invalid amount"):
                assert_not_zero(raw_amount)
            end
            repay_debt_internal(repayer, beneficiary, token, amount, raw_amount)

            return (raw_amount=raw_amount, face_amount=amount)
        end
    end

    # ASSUMPTION: `repay_amount` = `raw_amount` * Debt Accumulator
    # ASSUMPTION: it's always called by `repay_debt_route_internal`
    # ASSUMPTION: raw_amount is non zero
    func repay_debt_internal{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr : BitwiseBuiltin*,
    }(repayer : felt, beneficiary : felt, token : felt, repay_amount : felt, raw_amount : felt):
        alloc_locals

        let (this_address) = get_contract_address()

        let (_, updated_debt_accumulator) = update_accumulators(token)

        #
        # Checks
        #

        # No need to check if user is overpaying, as `SafeMath.sub` below will fail anyways
        # No need to check collateral value. Always allow repaying even if it's undercollateralized

        #
        # Effects
        #

        # Updates user debt data
        let (raw_user_debt_before) = raw_user_debts.read(beneficiary, token)
        let (raw_user_debt_after) = SafeMath.sub(raw_user_debt_before, raw_amount)
        raw_user_debts.write(beneficiary, token, raw_user_debt_after)

        set_user_has_debt(beneficiary, token, raw_user_debt_before, raw_user_debt_after)

        # Updates interest rate
        Internal.update_rates_and_raw_total_debt(
            token=token,
            updated_debt_accumulator=updated_debt_accumulator,
            is_delta_reserve_balance_negative=FALSE,
            abs_delta_reserve_balance=repay_amount,
            is_delta_raw_total_debt_negative=TRUE,
            abs_delta_raw_total_debt=raw_amount,
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

        let (updated_lending_accumulator) = View.get_lending_accumulator(token)
        let (updated_debt_accumulator) = View.get_debt_accumulator(token)

        AccumulatorsSync.emit(token, updated_lending_accumulator, updated_debt_accumulator)

        # It's okay to call this function here as the updated accumulators haven't been written into
        # storage yet
        let (amount_to_treasury) = View.get_pending_treasury_amount(token)

        # No need to check reserve existence since it's done in `get_lending_accumulator` and
        # `get_debt_accumulator`
        let (z_token_address) = reserves.read_z_token_address(token)

        reserves.write_accumulators(
            token, block_timestamp, updated_lending_accumulator, updated_debt_accumulator
        )

        # No need to check whether tresury address is zero as amount would be zero anyways
        if amount_to_treasury != 0:
            let (treasury_addr) = treasury.read()
            IZToken.mint(
                contract_address=z_token_address, to=treasury_addr, amount=amount_to_treasury
            )

            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end

        return (
            lending_accumulator=updated_lending_accumulator,
            debt_accumulator=updated_debt_accumulator,
        )
    end

    func update_rates_and_raw_total_debt{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(
        token : felt,
        updated_debt_accumulator : felt,
        is_delta_reserve_balance_negative : felt,
        abs_delta_reserve_balance : felt,
        is_delta_raw_total_debt_negative : felt,
        abs_delta_raw_total_debt : felt,
    ):
        alloc_locals

        let (this_address) = get_contract_address()

        let (
            interest_rate_model, raw_total_debt_before
        ) = reserves.read_interest_rate_model_and_raw_total_debt(token)

        # Makes sure reserve exists
        # (the caller must check it's enabled if needed since it's not validated here)
        with_attr error_message("Market: reserve not found"):
            assert_not_zero(interest_rate_model)
        end

        let (reserve_balance_before_u256) = IERC20.balanceOf(
            contract_address=token, account=this_address
        )
        let (reserve_balance_before) = SafeCast.uint256_to_felt(reserve_balance_before_u256)

        local reserve_balance_after : felt
        if is_delta_reserve_balance_negative == TRUE:
            let (res) = SafeMath.sub(reserve_balance_before, abs_delta_reserve_balance)
            reserve_balance_after = res
        else:
            let (res) = SafeMath.add(reserve_balance_before, abs_delta_reserve_balance)
            reserve_balance_after = res
        end

        local raw_total_debt_after : felt
        if is_delta_raw_total_debt_negative == TRUE:
            let (res) = SafeMath.sub(raw_total_debt_before, abs_delta_raw_total_debt)
            raw_total_debt_after = res
        else:
            let (res) = SafeMath.add(raw_total_debt_before, abs_delta_raw_total_debt)
            raw_total_debt_after = res
        end

        let (scaled_up_total_debt_after) = SafeDecimalMath.mul(
            raw_total_debt_after, updated_debt_accumulator
        )
        let (new_lending_rate, new_borrowing_rate) = IInterestRateModel.get_interest_rates(
            contract_address=interest_rate_model,
            reserve_balance=reserve_balance_after,
            total_debt=scaled_up_total_debt_after,
        )

        # Writes to storage
        reserves.write_rates(token, new_lending_rate, new_borrowing_rate)
        if raw_total_debt_before != raw_total_debt_after:
            reserves.write_raw_total_debt(token, raw_total_debt_after)
        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end

        InterestRatesSync.emit(token, new_lending_rate, new_borrowing_rate)

        return ()
    end

    # Checks reserve exists and returns full reserve data
    func assert_reserve_exists{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token : felt
    ):
        let (z_token) = reserves.read_z_token_address(token)
        with_attr error_message("Market: reserve not found"):
            assert_not_zero(z_token)
        end
        return ()
    end

    # Checks reserve is enabled and returns full reserve data
    func assert_reserve_enabled{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token : felt
    ):
        let (enabled) = reserves.read_enabled(token)
        with_attr error_message("Market: reserve not enabled"):
            assert_not_zero(enabled)
        end
        return ()
    end
end
