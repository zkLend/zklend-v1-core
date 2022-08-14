# SPDX-License-Identifier: BUSL-1.1

%lang starknet

@storage_var
func market() -> (res : felt):
end

@storage_var
func underlying() -> (res : felt):
end

@storage_var
func token_name() -> (name : felt):
end

@storage_var
func token_symbol() -> (symbol : felt):
end

@storage_var
func token_decimals() -> (decimals : felt):
end

@storage_var
func raw_total_supply() -> (total_supply : felt):
end

@storage_var
func raw_balances(account : felt) -> (balance : felt):
end

@storage_var
func allowances(owner : felt, spender : felt) -> (allowance : felt):
end
