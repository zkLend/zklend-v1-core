# SPDX-License-Identifier: MIT

%lang starknet

from zklend.internals.Market.structs import Structs

@contract_interface
namespace IMarket:
    #
    # Getters
    #

    func get_reserve_data(token : felt) -> (data : Structs.ReserveData):
    end

    func get_lending_accumulator(token : felt) -> (res : felt):
    end

    func get_debt_accumulator(token : felt) -> (res : felt):
    end

    func get_pending_treasury_amount(token : felt) -> (res : felt):
    end

    func get_total_debt_for_token(token : felt) -> (debt : felt):
    end

    func get_user_debt_for_token(user : felt, token : felt) -> (debt : felt):
    end

    func get_user_flags(user : felt) -> (map : felt):
    end

    func is_user_undercollateralized(user : felt, apply_borrow_factor : felt) -> (
        is_undercollateralized : felt
    ):
    end

    func is_collateral_enabled(user : felt, token : felt) -> (enabled : felt):
    end

    func user_has_debt(user : felt) -> (has_debt : felt):
    end

    #
    # Permissionless entrypoints
    #

    func deposit(token : felt, amount : felt):
    end

    func withdraw(token : felt, amount : felt):
    end

    func withdraw_all(token : felt):
    end

    func borrow(token : felt, amount : felt):
    end

    func repay(token : felt, amount : felt):
    end

    func repay_all(token : felt):
    end

    func enable_collateral(token : felt):
    end

    func disable_collateral(token : felt):
    end

    func liquidate(user : felt, debt_token : felt, amount : felt, collateral_token : felt):
    end

    func flash_loan(
        receiver : felt, token : felt, amount : felt, calldata_len : felt, calldata : felt*
    ):
    end

    #
    # Permissioned entrypoints
    #

    func add_reserve(
        token : felt,
        z_token : felt,
        interest_rate_model : felt,
        collateral_factor : felt,
        borrow_factor : felt,
        reserve_factor : felt,
        flash_loan_fee : felt,
        liquidation_bonus : felt,
    ):
    end

    func set_treasury(new_treasury : felt):
    end

    func transfer_ownership(new_owner : felt):
    end

    func renounce_ownership():
    end
end
