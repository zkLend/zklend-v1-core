#[starknet::contract]
mod PragmaOracleAdapter {
    use traits::Into;

    use starknet::ContractAddress;

    // Hack to simulate the `crate` keyword
    use super::super::super as crate;

    use crate::interfaces::{
        IPragmaOracleDispatcher, IPragmaOracleDispatcherTrait, IPriceOracleSource,
        PragmaOracleSpotMedian, PriceWithUpdateTime
    };
    use crate::libraries::{pow, safe_math};

    // These two consts MUST be the same.
    const TARGET_DECIMALS: felt252 = 8;
    const TARGET_DECIMALS_U256: u256 = 8;

    #[storage]
    struct Storage {
        oracle: ContractAddress,
        pair: felt252
    }

    #[constructor]
    fn constructor(ref self: ContractState, oracle: ContractAddress, pair: felt252) {
        self.oracle.write(oracle);
        self.pair.write(pair);
    }

    #[external(v0)]
    impl IPriceOracleSourceImpl of IPriceOracleSource<ContractState> {
        fn get_price(self: @ContractState) -> felt252 {
            get_data(self).price
        }

        fn get_price_with_time(self: @ContractState) -> PriceWithUpdateTime {
            get_data(self)
        }
    }

    fn get_data(self: @ContractState) -> PriceWithUpdateTime {
        let oracle_addr = self.oracle.read();
        let pair_key = self.pair.read();

        let median = IPragmaOracleDispatcher {
            contract_address: oracle_addr
        }.get_spot_median(pair_key);

        let scaled_price = scale_price(median.price, median.decimals);
        PriceWithUpdateTime { price: scaled_price, update_time: median.last_updated_timestamp }
    }

    fn scale_price(price: felt252, decimals: felt252) -> felt252 {
        if decimals == TARGET_DECIMALS {
            price
        } else {
            let should_scale_up = Into::<_, u256>::into(decimals) < TARGET_DECIMALS_U256;
            if should_scale_up {
                let multiplier = pow::ten_pow(TARGET_DECIMALS - decimals);
                let scaled_price = safe_math::mul(price, multiplier);
                scaled_price
            } else {
                let multiplier = pow::ten_pow(decimals - TARGET_DECIMALS);
                let scaled_price = safe_math::div(price, multiplier);
                scaled_price
            }
        }
    }
}
