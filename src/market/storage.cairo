// Storage cheats to enable efficient access to selected fields for larges structs in storage.
//
// WARN: the code here relies on compiler implementation details :/
//
// TODO: implement a codegen tool for this to avoid human errors.

use result::ResultTrait;

use starknet::{ContractAddress, Store};

use super::errors::INVALID_STORAGE as E;

use super::Market as contract;

use contract::reserves::ContractState as Reserves;
use contract::reservesContractStateTrait;

// These are hacks that depend on compiler implementation details :(
// But they're needed for refactoring the contract code into modules like this one.

// Address domain
const D: u32 = 0_u32;

#[derive(Drop)]
struct StorageBatch1 {
    interest_rate_model: ContractAddress,
    raw_total_debt: felt252
}

#[derive(Drop)]
struct StorageBatch2 {
    decimals: felt252,
    z_token_address: ContractAddress,
    collateral_factor: felt252
}

#[derive(Drop)]
struct StorageBatch3 {
    reserve_factor: felt252,
    last_update_timestamp: felt252,
    lending_accumulator: felt252,
    current_lending_rate: felt252
}

#[derive(Drop)]
struct StorageBatch4 {
    last_update_timestamp: felt252,
    debt_accumulator: felt252,
    current_borrowing_rate: felt252
}

#[derive(Drop)]
struct StorageBatch5 {
    z_token_address: ContractAddress,
    reserve_factor: felt252,
    last_update_timestamp: felt252,
    lending_accumulator: felt252,
    current_lending_rate: felt252
}

#[derive(Drop)]
struct StorageBatch6 {
    z_token_address: ContractAddress,
    reserve_factor: felt252,
    lending_accumulator: felt252,
    debt_accumulator: felt252,
    raw_total_debt: felt252
}

trait ReservesStorageShortcuts<T> {
    fn read_enabled(self: @T, token: ContractAddress) -> bool;

    fn read_decimals(self: @T, token: ContractAddress) -> felt252;

    fn read_z_token_address(self: @T, token: ContractAddress) -> ContractAddress;

    fn read_borrow_factor(self: @T, token: ContractAddress) -> felt252;

    fn read_raw_total_debt(self: @T, token: ContractAddress) -> felt252;

    fn read_flash_loan_fee(self: @T, token: ContractAddress) -> felt252;

    fn read_debt_limit(self: @T, token: ContractAddress) -> felt252;

    fn read_interest_rate_model_and_raw_total_debt(
        self: @T, token: ContractAddress
    ) -> StorageBatch1;

    fn read_for_get_user_collateral_usd_value_for_token(
        self: @T, token: ContractAddress
    ) -> StorageBatch2;

    fn read_for_get_lending_accumulator(self: @T, token: ContractAddress) -> StorageBatch3;

    fn read_for_get_debt_accumulator(self: @T, token: ContractAddress) -> StorageBatch4;

    fn read_for_get_pending_treasury_amount(self: @T, token: ContractAddress) -> StorageBatch5;

    fn read_for_settle_extra_reserve_balance(self: @T, token: ContractAddress) -> StorageBatch6;

    fn write_lending_accumulator(self: @T, token: ContractAddress, lending_accumulator: felt252);

    fn write_raw_total_debt(self: @T, token: ContractAddress, raw_total_debt: felt252);

    fn write_debt_limit(self: @T, token: ContractAddress, debt_limit: felt252);

    fn write_accumulators(
        self: @T,
        token: ContractAddress,
        last_update_timestamp: felt252,
        lending_accumulator: felt252,
        debt_accumulator: felt252
    );

    fn write_rates(
        self: @T,
        token: ContractAddress,
        current_lending_rate: felt252,
        current_borrowing_rate: felt252
    );
}

impl ReservesStorageShortcutsImpl of ReservesStorageShortcuts<Reserves> {
    fn read_enabled(self: @Reserves, token: ContractAddress) -> bool {
        let base = self.address(token);

        let enabled = Store::<bool>::read(D, base).expect(E);

        enabled
    }

    fn read_decimals(self: @Reserves, token: ContractAddress) -> felt252 {
        let base = self.address(token);

        let decimals = Store::<felt252>::read_at_offset(D, base, 1).expect(E);

        decimals
    }

    fn read_z_token_address(self: @Reserves, token: ContractAddress) -> ContractAddress {
        let base = self.address(token);

        let z_token_address = Store::<ContractAddress>::read_at_offset(D, base, 2).expect(E);

        z_token_address
    }

    fn read_borrow_factor(self: @Reserves, token: ContractAddress) -> felt252 {
        let base = self.address(token);

        let borrow_factor = Store::<felt252>::read_at_offset(D, base, 5).expect(E);

        borrow_factor
    }

    fn read_raw_total_debt(self: @Reserves, token: ContractAddress) -> felt252 {
        let base = self.address(token);

        let raw_total_debt = Store::<felt252>::read_at_offset(D, base, 12).expect(E);

        raw_total_debt
    }

    fn read_flash_loan_fee(self: @Reserves, token: ContractAddress) -> felt252 {
        let base = self.address(token);

        let flash_loan_fee = Store::<felt252>::read_at_offset(D, base, 13).expect(E);

        flash_loan_fee
    }

    fn read_debt_limit(self: @Reserves, token: ContractAddress) -> felt252 {
        let base = self.address(token);

        let debt_limit = Store::<felt252>::read_at_offset(D, base, 15).expect(E);

        debt_limit
    }

    fn read_interest_rate_model_and_raw_total_debt(
        self: @Reserves, token: ContractAddress
    ) -> StorageBatch1 {
        let base = self.address(token);

        let interest_rate_model = Store::<ContractAddress>::read_at_offset(D, base, 3).expect(E);
        let raw_total_debt = Store::<felt252>::read_at_offset(D, base, 12).expect(E);

        StorageBatch1 { interest_rate_model, raw_total_debt }
    }

    fn read_for_get_user_collateral_usd_value_for_token(
        self: @Reserves, token: ContractAddress
    ) -> StorageBatch2 {
        let base = self.address(token);

        let decimals = Store::<felt252>::read_at_offset(D, base, 1).expect(E);
        let z_token_address = Store::<ContractAddress>::read_at_offset(D, base, 2).expect(E);
        let collateral_factor = Store::<felt252>::read_at_offset(D, base, 4).expect(E);

        StorageBatch2 { decimals, z_token_address, collateral_factor }
    }

    fn read_for_get_lending_accumulator(self: @Reserves, token: ContractAddress) -> StorageBatch3 {
        let base = self.address(token);

        let reserve_factor = Store::<felt252>::read_at_offset(D, base, 6).expect(E);
        let last_update_timestamp = Store::<felt252>::read_at_offset(D, base, 7).expect(E);
        let lending_accumulator = Store::<felt252>::read_at_offset(D, base, 8).expect(E);
        let current_lending_rate = Store::<felt252>::read_at_offset(D, base, 10).expect(E);

        StorageBatch3 {
            reserve_factor, last_update_timestamp, lending_accumulator, current_lending_rate
        }
    }

    fn read_for_get_debt_accumulator(self: @Reserves, token: ContractAddress) -> StorageBatch4 {
        let base = self.address(token);

        let last_update_timestamp = Store::<felt252>::read_at_offset(D, base, 7).expect(E);
        let debt_accumulator = Store::<felt252>::read_at_offset(D, base, 9).expect(E);
        let current_borrowing_rate = Store::<felt252>::read_at_offset(D, base, 11).expect(E);

        StorageBatch4 { last_update_timestamp, debt_accumulator, current_borrowing_rate }
    }

    fn read_for_get_pending_treasury_amount(
        self: @Reserves, token: ContractAddress
    ) -> StorageBatch5 {
        let base = self.address(token);

        let z_token_address = Store::<ContractAddress>::read_at_offset(D, base, 2).expect(E);
        let reserve_factor = Store::<felt252>::read_at_offset(D, base, 6).expect(E);
        let last_update_timestamp = Store::<felt252>::read_at_offset(D, base, 7).expect(E);
        let lending_accumulator = Store::<felt252>::read_at_offset(D, base, 8).expect(E);
        let current_lending_rate = Store::<felt252>::read_at_offset(D, base, 10).expect(E);

        StorageBatch5 {
            z_token_address,
            reserve_factor,
            last_update_timestamp,
            lending_accumulator,
            current_lending_rate
        }
    }

    fn read_for_settle_extra_reserve_balance(
        self: @Reserves, token: ContractAddress
    ) -> StorageBatch6 {
        let base = self.address(token);

        let z_token_address = Store::<ContractAddress>::read_at_offset(D, base, 2).expect(E);
        let reserve_factor = Store::<felt252>::read_at_offset(D, base, 6).expect(E);
        let lending_accumulator = Store::<felt252>::read_at_offset(D, base, 8).expect(E);
        let debt_accumulator = Store::<felt252>::read_at_offset(D, base, 9).expect(E);
        let raw_total_debt = Store::<felt252>::read_at_offset(D, base, 12).expect(E);

        StorageBatch6 {
            z_token_address, reserve_factor, lending_accumulator, debt_accumulator, raw_total_debt
        }
    }

    fn write_lending_accumulator(
        self: @Reserves, token: ContractAddress, lending_accumulator: felt252
    ) {
        let base = self.address(token);

        Store::<felt252>::write_at_offset(D, base, 8, lending_accumulator).expect(E);
    }

    fn write_raw_total_debt(self: @Reserves, token: ContractAddress, raw_total_debt: felt252) {
        let base = self.address(token);

        Store::<felt252>::write_at_offset(D, base, 12, raw_total_debt).expect(E);
    }

    fn write_debt_limit(self: @Reserves, token: ContractAddress, debt_limit: felt252) {
        let base = self.address(token);

        Store::<felt252>::write_at_offset(D, base, 15, debt_limit).expect(E);
    }

    fn write_accumulators(
        self: @Reserves,
        token: ContractAddress,
        last_update_timestamp: felt252,
        lending_accumulator: felt252,
        debt_accumulator: felt252
    ) {
        let base = self.address(token);

        Store::<felt252>::write_at_offset(D, base, 7, last_update_timestamp).expect(E);
        Store::<felt252>::write_at_offset(D, base, 8, lending_accumulator).expect(E);
        Store::<felt252>::write_at_offset(D, base, 9, debt_accumulator).expect(E);
    }

    fn write_rates(
        self: @Reserves,
        token: ContractAddress,
        current_lending_rate: felt252,
        current_borrowing_rate: felt252
    ) {
        let base = self.address(token);

        Store::<felt252>::write_at_offset(D, base, 10, current_lending_rate).expect(E);
        Store::<felt252>::write_at_offset(D, base, 11, current_borrowing_rate).expect(E);
    }
}
