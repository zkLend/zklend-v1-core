#[starknet::contract]
mod MockPragmaOracle {
    use starknet::ContractAddress;

    use zklend::interfaces::{IPragmaOracle, PragmaDataType, PragmaPricesResponse};

    use super::super::IMockPragmaOracle;

    #[storage]
    struct Storage {
        pair_id: felt252,
        price: u128,
        decimals: u32,
        last_updated_timestamp: u64,
        num_sources_aggregated: u32
    }

    #[abi(embed_v0)]
    impl IPragmaOracleImpl of IPragmaOracle<ContractState> {
        fn get_data_median(
            self: @ContractState, data_type: PragmaDataType
        ) -> PragmaPricesResponse {
            PragmaPricesResponse {
                price: self.price.read(),
                decimals: self.decimals.read(),
                last_updated_timestamp: self.last_updated_timestamp.read(),
                num_sources_aggregated: self.num_sources_aggregated.read(),
                expiration_timestamp: Option::None,
            }
        }
    }

    #[abi(embed_v0)]
    impl IMockPragmaOracleImpl of IMockPragmaOracle<ContractState> {
        fn set_price(
            ref self: ContractState,
            pair_id: felt252,
            price: u128,
            decimals: u32,
            last_updated_timestamp: u64,
            num_sources_aggregated: u32
        ) {
            self.pair_id.write(pair_id);
            self.price.write(price);
            self.decimals.write(decimals);
            self.last_updated_timestamp.write(last_updated_timestamp);
            self.num_sources_aggregated.write(num_sources_aggregated);
        }
    }
}
