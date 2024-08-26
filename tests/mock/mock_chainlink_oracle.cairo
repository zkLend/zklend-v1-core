#[starknet::contract]
mod MockChainlinkOracle {
    use starknet::ContractAddress;

    use zklend::interfaces::{IChainlinkOracle, ChainlinkPricesResponse};

    use super::super::IMockChainlinkOracle;

    #[storage]
    struct Storage {
        round_id: felt252,
        answer: u128,
        block_num: u64,
        started_at: u64,
        updated_at: u64,
    }

    #[abi(embed_v0)]
    impl IChainlinkOracleImpl of IChainlinkOracle<ContractState> {
        fn latest_round_data(self: @ContractState) -> ChainlinkPricesResponse {
            ChainlinkPricesResponse {
                round_id: self.round_id.read(),
                answer: self.answer.read(),
                block_num: self.block_num.read(),
                started_at: self.started_at.read(),
                updated_at: self.updated_at.read(),
            }
        }

        fn decimals(self: @ContractState) -> u8 {
            8
        }
    }

    #[abi(embed_v0)]
    impl IMockChainlinkOracleImpl of IMockChainlinkOracle<ContractState> {
        fn set_price(
            ref self: ContractState,
            round_id: felt252,
            answer: u128,
            block_num: u64,
            started_at: u64,
            updated_at: u64
        ) {
            self.round_id.write(round_id);
            self.answer.write(answer);
            self.block_num.write(block_num);
            self.started_at.write(started_at);
            self.updated_at.write(updated_at);
        }
    }
}
