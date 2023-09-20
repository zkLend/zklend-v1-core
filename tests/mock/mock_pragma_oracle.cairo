#[starknet::contract]
mod MockPragmaOracle {
    use starknet::ContractAddress;

    use zklend::interfaces::{IPragmaOracle, PragmaOracleSpotMedian};

    use super::super::IMockPragmaOracle;

    #[storage]
    struct Storage {
        pair_id: felt252,
        price: felt252,
        decimals: felt252,
        last_updated_timestamp: felt252,
        num_sources_aggregated: felt252
    }

    #[external(v0)]
    impl IPragmaOracleImpl of IPragmaOracle<ContractState> {
        fn get_spot_median(self: @ContractState, pair_id: felt252) -> PragmaOracleSpotMedian {
            PragmaOracleSpotMedian {
                price: self.price.read(),
                decimals: self.decimals.read(),
                last_updated_timestamp: self.last_updated_timestamp.read(),
                num_sources_aggregated: self.num_sources_aggregated.read()
            }
        }
    }

    #[external(v0)]
    impl IMockPragmaOracleImpl of IMockPragmaOracle<ContractState> {
        fn set_price(
            ref self: ContractState,
            pair_id: felt252,
            price: felt252,
            decimals: felt252,
            last_updated_timestamp: felt252,
            num_sources_aggregated: felt252
        ) {
            self.pair_id.write(pair_id);
            self.price.write(price);
            self.decimals.write(decimals);
            self.last_updated_timestamp.write(last_updated_timestamp);
            self.num_sources_aggregated.write(num_sources_aggregated);
        }
    }
}
