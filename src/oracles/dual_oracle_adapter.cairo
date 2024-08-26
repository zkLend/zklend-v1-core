mod errors {
    const DIVERGING_UPSTREAMS: felt252 = 'DUAL_DIVERGING_UPSTREAMS';
}

/// An oracle implementation that implements `IPriceOracleSource` but is backed by two upstream
/// `IPriceOracleSource` oracles. The final output is the average price of the upstreams as long as
/// they don't diverge beyond a configured threshold; otherwise an error is thrown.
#[starknet::contract]
mod DualOracleAdapter {
    use starknet::ContractAddress;

    // Hack to simulate the `crate` keyword
    use super::super::super as crate;

    use crate::interfaces::{
        IPriceOracleSource, IPriceOracleSourceDispatcher, IPriceOracleSourceDispatcherTrait,
        PriceWithUpdateTime
    };
    use crate::libraries::safe_decimal_math;

    use super::errors;

    #[storage]
    struct Storage {
        upstream_0: ContractAddress,
        upstream_1: ContractAddress,
        threshold: felt252,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        upstream_0: ContractAddress,
        upstream_1: ContractAddress,
        threshold: felt252
    ) {
        self.upstream_0.write(upstream_0);
        self.upstream_1.write(upstream_1);
        self.threshold.write(threshold);
    }

    #[abi(embed_v0)]
    impl IPriceOracleSourceImpl of IPriceOracleSource<ContractState> {
        fn get_price(self: @ContractState) -> felt252 {
            get_data(self).price
        }

        fn get_price_with_time(self: @ContractState) -> PriceWithUpdateTime {
            get_data(self)
        }
    }

    fn get_data(self: @ContractState) -> PriceWithUpdateTime {
        // There is no need to scale the prices as all `IPriceOracleSource` implementations are
        // guaranteed to return at target decimals.
        let price_0 = IPriceOracleSourceDispatcher { contract_address: self.upstream_0.read() }
            .get_price_with_time();
        let price_1 = IPriceOracleSourceDispatcher { contract_address: self.upstream_1.read() }
            .get_price_with_time();

        let price_0_u256: u256 = price_0.price.into();
        let price_1_u256: u256 = price_1.price.into();

        let (lower_felt, lower, upper) = if price_0_u256 < price_1_u256 {
            (price_0.price, price_0_u256, price_1_u256)
        } else {
            (price_1.price, price_1_u256, price_0_u256)
        };

        assert(
            lower
                + Into::<
                    _, u256
                >::into(safe_decimal_math::mul(lower_felt, self.threshold.read())) >= upper,
            errors::DIVERGING_UPSTREAMS
        );

        PriceWithUpdateTime {
            price: ((price_0_u256 + price_1_u256) / 2).try_into().unwrap(),
            update_time: if Into::<
                _, u256
                >::into(price_0.update_time) < Into::<
                _, u256
            >::into(price_1.update_time) {
                price_0.update_time
            } else {
                price_1.update_time
            },
        }
    }
}
