# SPDX-License-Identifier: BUSL-1.1

%lang starknet

@contract_interface
namespace IZToken:
    func mint(to : felt, amount : felt) -> (zero_balance_before : felt):
    end

    func burn(user : felt, amount : felt):
    end
end
