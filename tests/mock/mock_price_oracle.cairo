#[starknet::contract]
mod MockPriceOracle {
    use starknet::ContractAddress;

    use zklend::interfaces::{IPriceOracle, PriceWithUpdateTime};

    use super::super::IMockPriceOracle;

    #[storage]
    struct Storage {
        prices: LegacyMap::<ContractAddress, PriceData>
    }

    #[derive(Drop, starknet::Store)]
    struct PriceData {
        price: felt252,
        update_time: felt252
    }

    #[external(v0)]
    impl IPriceOracleImpl of IPriceOracle<ContractState> {
        fn get_price(self: @ContractState, token: ContractAddress) -> felt252 {
            let data = self.prices.read(token);
            data.price
        }

        fn get_price_with_time(
            self: @ContractState, token: ContractAddress
        ) -> PriceWithUpdateTime {
            let data = self.prices.read(token);
            return PriceWithUpdateTime { price: data.price, update_time: data.update_time };
        }
    }

    #[external(v0)]
    impl IMockPriceOracleImpl of IMockPriceOracle<ContractState> {
        fn set_price(
            ref self: ContractState, token: ContractAddress, price: felt252, update_time: felt252
        ) {
            self.prices.write(token, PriceData { price, update_time });
        }
    }
}
