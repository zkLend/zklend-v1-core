# SPDX-License-Identifier: BUSL-1.1

%lang starknet

@contract_interface
namespace IZToken:
    func felt_balance_of(account : felt) -> (balance : felt):
    end

    func underlying_token() -> (token : felt):
    end

    func mint(to : felt, amount : felt) -> (zero_balance_before : felt):
    end

    func burn(user : felt, amount : felt):
    end

    func burn_all(user : felt) -> (amount_burnt : felt):
    end

    func move(from_account : felt, to_account : felt, amount : felt):
    end
end
