# SPDX-License-Identifier: BUSL-1.1

%lang starknet

@contract_interface
namespace IMarket:
    func get_lending_accumulator(token : felt) -> (res : felt):
    end

    func get_debt_accumulator(token : felt) -> (res : felt):
    end

    func is_user_undercollateralized(user : felt, apply_borrow_factor : felt) -> (
        is_undercollateralized : felt
    ):
    end

    func is_collateral_enabled(user : felt, token : felt) -> (enabled : felt):
    end

    func flash_loan(
        receiver : felt, token : felt, amount : felt, calldata_len : felt, calldata : felt*
    ):
    end
end
