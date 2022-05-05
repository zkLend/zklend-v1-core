# SPDX-License-Identifier: BUSL-1.1

%lang starknet

@contract_interface
namespace IMarket:
    func get_lending_accumulator(token : felt) -> (res : felt):
    end

    func get_debt_accumulator(token : felt) -> (res : felt):
    end
end
