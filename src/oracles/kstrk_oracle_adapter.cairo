mod errors {
    const PRICE_OVERFLOW: felt252 = 'KSTRK_PRICE_OVERFLOW';
}

/// An oracle implementation that prices the `kSTRK` token by multiplying the `STRK` price from
/// another "upstream" adapter by the `kSTRK/STRK` exchange rate.
#[starknet::contract]
mod KstrkOracleAdapter {
    use starknet::{ContractAddress, get_block_timestamp};

    // Hack to simulate the `crate` keyword
    use super::super::super as crate;

    use crate::interfaces::{
        IERC20Dispatcher, IERC20DispatcherTrait, IKstrkPoolDispatcher, IKstrkPoolDispatcherTrait,
        IPriceOracleSource, IPriceOracleSourceDispatcher, IPriceOracleSourceDispatcherTrait,
        PriceWithUpdateTime
    };
    use crate::libraries::safe_decimal_math;

    use super::errors;

    #[storage]
    struct Storage {
        strk_upstream: ContractAddress,
        kstrk_pool: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, strk_upstream: ContractAddress, kstrk_pool: ContractAddress
    ) {
        self.strk_upstream.write(strk_upstream);
        self.kstrk_pool.write(kstrk_pool);
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
        let strk_price = IPriceOracleSourceDispatcher {
            contract_address: self.strk_upstream.read()
        }
            .get_price_with_time();

        let strk_price_u256: u256 = strk_price.price.into();

        let kstrk_pool = IKstrkPoolDispatcher { contract_address: self.kstrk_pool.read() };
        let kstrk_token = IERC20Dispatcher { contract_address: kstrk_pool.get_staked_token() };

        let pool_size: u256 = kstrk_pool.get_total_stake().into();
        let total_supply = kstrk_token.totalSupply();

        let kstrk_price: felt252 = (strk_price_u256 * pool_size / total_supply)
            .try_into()
            .expect(errors::PRICE_OVERFLOW);

        PriceWithUpdateTime { price: kstrk_price, update_time: get_block_timestamp().into() }
    }
}
