# SPDX-License-Identifier: MIT

%lang starknet

@contract_interface
namespace IInterestRateModel:
    func get_interest_rates(reserve_balance : felt, total_debt : felt) -> (
        lending_rate : felt, borrowing_rate : felt
    ):
    end
end
