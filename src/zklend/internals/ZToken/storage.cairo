// SPDX-License-Identifier: BUSL-1.1

%lang starknet

@storage_var
func market() -> (res: felt) {
}

@storage_var
func underlying() -> (res: felt) {
}

@storage_var
func token_name() -> (name: felt) {
}

@storage_var
func token_symbol() -> (symbol: felt) {
}

@storage_var
func token_decimals() -> (decimals: felt) {
}

@storage_var
func raw_total_supply() -> (total_supply: felt) {
}

@storage_var
func raw_balances(account: felt) -> (balance: felt) {
}

@storage_var
func allowances(owner: felt, spender: felt) -> (allowance: felt) {
}
