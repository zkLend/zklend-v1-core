# SPDX-License-Identifier: BUSL-1.1

%lang starknet

@contract_interface
namespace IInterestRateModel:
    func get_interest_rates(reserve_balance : felt, total_debt : felt) -> (
        supply_rate : felt, borrow_rate : felt
    ):
    end
end
