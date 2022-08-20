# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IZToken:
    #
    # Getters
    #

    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func decimals() -> (decimals : felt):
    end

    func totalSupply() -> (total_supply : Uint256):
    end

    func felt_total_supply() -> (total_supply : felt):
    end

    func balanceOf(account : felt) -> (balance : Uint256):
    end

    func felt_balance_of(account : felt) -> (balance : felt):
    end

    func allowance(owner : felt, spender : felt) -> (remaining : Uint256):
    end

    func felt_allowance(owner : felt, spender : felt) -> (remaining : felt):
    end

    func underlying_token() -> (token : felt):
    end

    func get_raw_total_supply() -> (raw_supply : felt):
    end

    func transfer(recipient : felt, amount : Uint256) -> (success : felt):
    end

    func felt_transfer(recipient : felt, amount : felt) -> (success : felt):
    end

    func transferFrom(sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    end

    func felt_transfer_from(sender : felt, recipient : felt, amount : felt) -> (success : felt):
    end

    func approve(spender : felt, amount : Uint256) -> (success : felt):
    end

    func felt_approve(spender : felt, amount : felt) -> (success : felt):
    end

    func transfer_all(recipient : felt):
    end

    #
    # Permissioned entrypoints
    #

    func mint(to : felt, amount : felt) -> (zero_balance_before : felt):
    end

    func burn(user : felt, amount : felt):
    end

    func burn_all(user : felt) -> (amount_burnt : felt):
    end

    func move(from_account : felt, to_account : felt, amount : felt):
    end
end
