/// A central oracle hub for connecting to different upstream oracles and exposing a single getter
/// to the core protocol.
#[starknet::contract]
mod DefaultPriceOracle {
    use starknet::ContractAddress;

    // Hack to simulate the `crate` keyword
    use super::super as crate;

    use crate::interfaces::{
        IDefaultPriceOracle, IPriceOracle, IPriceOracleSourceDispatcher,
        IPriceOracleSourceDispatcherTrait, PriceWithUpdateTime
    };
    use crate::libraries::ownable;

    #[storage]
    struct Storage {
        // token -> source
        sources: LegacyMap::<ContractAddress, ContractAddress>,
        // Unlike in `ZToken`, we don't need to maintain storage compatibility here as this
        // contract is not upgradeable.
        owner: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TokenSourceChanged: TokenSourceChanged,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct TokenSourceChanged {
        token: ContractAddress,
        source: ContractAddress
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        ownable::initializer(ref self, owner);
    }

    #[abi(embed_v0)]
    impl IPriceOracleImpl of IPriceOracle<ContractState> {
        fn get_price(self: @ContractState, token: ContractAddress) -> felt252 {
            let source = self.sources.read(token);
            IPriceOracleSourceDispatcher { contract_address: source }.get_price()
        }

        fn get_price_with_time(
            self: @ContractState, token: ContractAddress
        ) -> PriceWithUpdateTime {
            let source = self.sources.read(token);
            IPriceOracleSourceDispatcher { contract_address: source }.get_price_with_time()
        }
    }

    #[abi(embed_v0)]
    impl IDefaultPriceOracleImpl of IDefaultPriceOracle<ContractState> {
        fn set_token_source(
            ref self: ContractState, token: ContractAddress, source: ContractAddress
        ) {
            ownable::assert_only_owner(@self);

            self.sources.write(token, source);

            self.emit(Event::TokenSourceChanged(TokenSourceChanged { token, source }));
        }
    }

    impl DefaultPriceOracleOwnable of ownable::Ownable<ContractState> {
        fn read_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn write_owner(ref self: ContractState, owner: ContractAddress) {
            self.owner.write(owner);
        }

        fn emit_ownership_transferred(
            ref self: ContractState, previous_owner: ContractAddress, new_owner: ContractAddress
        ) {
            self
                .emit(
                    Event::OwnershipTransferred(OwnershipTransferred { previous_owner, new_owner })
                );
        }
    }
}

