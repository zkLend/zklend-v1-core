mod errors {
    const INVALID_TIMESTAMP: felt252 = 'PRAGMA_INVALID_TIMESTAMP';
    const STALED_PRICE: felt252 = 'PRAGMA_STALED_PRICE';
    const ZERO_PRICE: felt252 = 'PRAGMA_ZERO_PRICE';
}

#[starknet::contract]
mod PragmaOracleAdapter {
    use integer::u64_checked_sub;
    use option::OptionTrait;
    use traits::{Into, TryInto};

    use starknet::{ContractAddress, get_block_timestamp};

    // Hack to simulate the `crate` keyword
    use super::super::super as crate;

    use crate::interfaces::{
        IPragmaOracleDispatcher, IPragmaOracleDispatcherTrait, IPriceOracleSource,
        PragmaOracleSpotMedian, PriceWithUpdateTime
    };
    use crate::libraries::{pow, safe_math};

    use super::errors;

    // These two consts MUST be the same.
    const TARGET_DECIMALS: felt252 = 8;
    const TARGET_DECIMALS_U256: u256 = 8;

    #[storage]
    struct Storage {
        oracle: ContractAddress,
        pair: felt252,
        timeout: u64
    }

    #[constructor]
    fn constructor(ref self: ContractState, oracle: ContractAddress, pair: felt252, timeout: u64) {
        self.oracle.write(oracle);
        self.pair.write(pair);
        self.timeout.write(timeout);
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
        assert(median.price != 0, errors::ZERO_PRICE);

        // Block times are usually behind real world time by a bit. It's possible that the reported
        // last updated timestamp is in the (very near) future.
        let block_time: u64 = get_block_timestamp();
        let last_updated_timestamp: u64 = median
            .last_updated_timestamp
            .try_into()
            .expect(errors::INVALID_TIMESTAMP);

        let time_elasped: u64 = match u64_checked_sub(block_time, last_updated_timestamp) {
            Option::Some(value) => value,
            Option::None => 0,
        };
        let timeout = self.timeout.read();
        assert(time_elasped <= timeout, errors::STALED_PRICE);

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
