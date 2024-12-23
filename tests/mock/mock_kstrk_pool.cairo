use super::IMockKstrkPool;

#[starknet::contract]
mod MockKstrkPool {
    use starknet::ContractAddress;

    use super::IMockKstrkPool;

    #[storage]
    struct Storage {
        staked_token: ContractAddress,
        total_stake: u128,
    }

    #[abi(embed_v0)]
    impl IMockKstrkPoolImpl of IMockKstrkPool<ContractState> {
        fn get_staked_token(self: @ContractState) -> ContractAddress {
            self.staked_token.read()
        }

        fn get_total_stake(self: @ContractState) -> u128 {
            self.total_stake.read()
        }

        fn set_staked_token(ref self: ContractState, staked_token: ContractAddress) {
            self.staked_token.write(staked_token)
        }

        fn set_total_stake(ref self: ContractState, total_stake: u128) {
            self.total_stake.write(total_stake)
        }
    }
}
