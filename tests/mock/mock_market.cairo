use super::IMockMarket;

#[starknet::contract]
mod MockMarket {
    use starknet::ContractAddress;

    use zklend::interfaces::{IZTokenDispatcher, IZTokenDispatcherTrait};

    use super::IMockMarket;

    #[storage]
    struct Storage {
        lending_accumulator: LegacyMap::<ContractAddress, felt252>,
        debt_accumulator: LegacyMap::<ContractAddress, felt252>,
        collateral_enabled: LegacyMap::<(ContractAddress, ContractAddress), bool>,
        user_undercollateralized: LegacyMap::<ContractAddress, bool>,
        last_call_result: felt252
    }

    #[external(v0)]
    impl IMockMarketImpl of IMockMarket<ContractState> {
        fn get_lending_accumulator(self: @ContractState, token: ContractAddress) -> felt252 {
            self.lending_accumulator.read(token)
        }

        fn get_debt_accumulator(self: @ContractState, token: ContractAddress) -> felt252 {
            self.debt_accumulator.read(token)
        }

        fn is_user_undercollateralized(self: @ContractState, user: ContractAddress) -> bool {
            self.user_undercollateralized.read(user)
        }

        fn is_collateral_enabled(
            self: @ContractState, user: ContractAddress, token: ContractAddress
        ) -> bool {
            self.collateral_enabled.read((user, token))
        }

        fn get_last_call_result(self: @ContractState) -> felt252 {
            self.last_call_result.read()
        }

        fn set_lending_accumulator(
            ref self: ContractState, token: ContractAddress, value: felt252
        ) {
            self.lending_accumulator.write(token, value);
        }

        fn set_debt_accumulator(ref self: ContractState, token: ContractAddress, value: felt252) {
            self.debt_accumulator.write(token, value);
        }

        fn set_user_undercollateralized(
            ref self: ContractState, user: ContractAddress, value: bool
        ) {
            self.user_undercollateralized.write(user, value);
        }

        fn mint_z_token(
            ref self: ContractState, z_token: ContractAddress, to: ContractAddress, amount: felt252
        ) {
            IZTokenDispatcher { contract_address: z_token }.mint(to, amount);
        }

        fn burn_all_z_token(
            ref self: ContractState, z_token: ContractAddress, user: ContractAddress
        ) {
            let amount_burnt = IZTokenDispatcher { contract_address: z_token }.burn_all(user);
            self.last_call_result.write(amount_burnt);
        }
    }
}
