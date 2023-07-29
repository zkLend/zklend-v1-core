#[starknet::contract]
mod Account {
    use starknet::ContractAddress;

    use zklend::interfaces::{
        IMarketDispatcher, IMarketDispatcherTrait, ITestContractDispatcher,
        ITestContractDispatcherTrait, IZTokenDispatcher, IZTokenDispatcherTrait
    };

    use super::super::{IAccount, IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl IAccountImpl of IAccount<ContractState> {
        fn erc20_transfer(
            self: @ContractState,
            contract_address: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            IERC20Dispatcher { contract_address }.transfer(recipient, amount);
        }

        fn erc20_approve(
            self: @ContractState,
            contract_address: ContractAddress,
            spender: ContractAddress,
            amount: u256
        ) {
            IERC20Dispatcher { contract_address }.approve(spender, amount);
        }

        fn erc20_transfer_from(
            self: @ContractState,
            contract_address: ContractAddress,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            IERC20Dispatcher { contract_address }.transferFrom(sender, recipient, amount);
        }

        fn z_token_transfer_all(
            ref self: ContractState, contract_address: ContractAddress, recipient: ContractAddress
        ) -> felt252 {
            IZTokenDispatcher { contract_address }.transfer_all(recipient)
        }

        fn market_set_treasury(
            ref self: ContractState,
            contract_address: ContractAddress,
            new_treasury: ContractAddress
        ) {
            IMarketDispatcher { contract_address }.set_treasury(new_treasury)
        }

        fn market_set_debt_limit(
            ref self: ContractState,
            contract_address: ContractAddress,
            token: ContractAddress,
            limit: felt252
        ) {
            IMarketDispatcher { contract_address }.set_debt_limit(token, limit)
        }

        fn market_add_reserve(
            ref self: ContractState,
            contract_address: ContractAddress,
            token: ContractAddress,
            z_token: ContractAddress,
            interest_rate_model: ContractAddress,
            collateral_factor: felt252,
            borrow_factor: felt252,
            reserve_factor: felt252,
            flash_loan_fee: felt252,
            liquidation_bonus: felt252
        ) {
            IMarketDispatcher {
                contract_address
            }
                .add_reserve(
                    token,
                    z_token,
                    interest_rate_model,
                    collateral_factor,
                    borrow_factor,
                    reserve_factor,
                    flash_loan_fee,
                    liquidation_bonus
                )
        }

        fn market_deposit(
            ref self: ContractState,
            contract_address: ContractAddress,
            token: ContractAddress,
            amount: felt252
        ) {
            IMarketDispatcher { contract_address }.deposit(token, amount)
        }

        fn market_withdraw(
            ref self: ContractState,
            contract_address: ContractAddress,
            token: ContractAddress,
            amount: felt252
        ) {
            IMarketDispatcher { contract_address }.withdraw(token, amount)
        }

        fn market_withdraw_all(
            ref self: ContractState, contract_address: ContractAddress, token: ContractAddress
        ) {
            IMarketDispatcher { contract_address }.withdraw_all(token)
        }

        fn market_repay(
            ref self: ContractState,
            contract_address: ContractAddress,
            token: ContractAddress,
            amount: felt252
        ) {
            IMarketDispatcher { contract_address }.repay(token, amount)
        }

        fn market_repay_all(
            ref self: ContractState, contract_address: ContractAddress, token: ContractAddress
        ) {
            IMarketDispatcher { contract_address }.repay_all(token)
        }

        fn market_enable_collateral(
            ref self: ContractState, contract_address: ContractAddress, token: ContractAddress
        ) {
            IMarketDispatcher { contract_address }.enable_collateral(token)
        }

        fn market_disable_collateral(
            ref self: ContractState, contract_address: ContractAddress, token: ContractAddress
        ) {
            IMarketDispatcher { contract_address }.disable_collateral(token)
        }

        fn market_borrow(
            ref self: ContractState,
            contract_address: ContractAddress,
            token: ContractAddress,
            amount: felt252
        ) {
            IMarketDispatcher { contract_address }.borrow(token, amount)
        }

        fn market_liquidate(
            ref self: ContractState,
            contract_address: ContractAddress,
            user: ContractAddress,
            debt_token: ContractAddress,
            amount: felt252,
            collateral_token: ContractAddress
        ) {
            IMarketDispatcher {
                contract_address
            }.liquidate(user, debt_token, amount, collateral_token)
        }
    }
}
