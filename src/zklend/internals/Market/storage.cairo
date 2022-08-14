# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.internals.Market.structs import Structs

@storage_var
func oracle() -> (oracle : felt):
end

@storage_var
func treasury() -> (oracle : felt):
end

@storage_var
func reserves(token : felt) -> (res : Structs.ReserveData):
end

@storage_var
func reserve_count() -> (count : felt):
end

@storage_var
func reserve_tokens(index : felt) -> (token : felt):
end

@storage_var
func reserve_indices(token : felt) -> (index : felt):
end

@storage_var
func collateral_usages(user : felt) -> (map : felt):
end

@storage_var
func raw_user_debts(user : felt, token : felt) -> (debt : felt):
end
