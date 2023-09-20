use starknet::ContractAddress;

mod account;

mod mock_market;

mod mock_price_oracle;

mod mock_pragma_oracle;

mod flash_loan_handler;

mod erc20;

#[starknet::interface]
trait IERC20<TContractState> {
    fn name(self: @TContractState) -> felt252;

    fn symbol(self: @TContractState) -> felt252;

    fn decimals(self: @TContractState) -> u8;

    fn totalSupply(self: @TContractState) -> u256;

    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;

    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;

    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;

    fn transferFrom(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;

    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
trait IAccount<TContractState> {
    fn erc20_transfer(
        self: @TContractState,
        contract_address: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    );

    fn erc20_approve(
        self: @TContractState,
        contract_address: ContractAddress,
        spender: ContractAddress,
        amount: u256
    );

    fn erc20_transfer_from(
        self: @TContractState,
        contract_address: ContractAddress,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    );

    fn z_token_transfer_all(
        ref self: TContractState, contract_address: ContractAddress, recipient: ContractAddress
    ) -> felt252;

    fn market_set_treasury(
        ref self: TContractState, contract_address: ContractAddress, new_treasury: ContractAddress
    );

    fn market_set_debt_limit(
        ref self: TContractState,
        contract_address: ContractAddress,
        token: ContractAddress,
        limit: felt252
    );

    fn market_add_reserve(
        ref self: TContractState,
        contract_address: ContractAddress,
        token: ContractAddress,
        z_token: ContractAddress,
        interest_rate_model: ContractAddress,
        collateral_factor: felt252,
        borrow_factor: felt252,
        reserve_factor: felt252,
        flash_loan_fee: felt252,
        liquidation_bonus: felt252
    );

    fn market_deposit(
        ref self: TContractState,
        contract_address: ContractAddress,
        token: ContractAddress,
        amount: felt252
    );

    fn market_withdraw(
        ref self: TContractState,
        contract_address: ContractAddress,
        token: ContractAddress,
        amount: felt252
    );

    fn market_withdraw_all(
        ref self: TContractState, contract_address: ContractAddress, token: ContractAddress
    );

    fn market_repay(
        ref self: TContractState,
        contract_address: ContractAddress,
        token: ContractAddress,
        amount: felt252
    );

    fn market_repay_all(
        ref self: TContractState, contract_address: ContractAddress, token: ContractAddress
    );

    fn market_enable_collateral(
        ref self: TContractState, contract_address: ContractAddress, token: ContractAddress
    );

    fn market_disable_collateral(
        ref self: TContractState, contract_address: ContractAddress, token: ContractAddress
    );

    fn market_borrow(
        ref self: TContractState,
        contract_address: ContractAddress,
        token: ContractAddress,
        amount: felt252
    );

    fn market_liquidate(
        ref self: TContractState,
        contract_address: ContractAddress,
        user: ContractAddress,
        debt_token: ContractAddress,
        amount: felt252,
        collateral_token: ContractAddress
    );
}

#[starknet::interface]
trait IMockMarket<TContractState> {
    //
    // Getters
    //

    fn get_lending_accumulator(self: @TContractState, token: ContractAddress) -> felt252;

    fn get_debt_accumulator(self: @TContractState, token: ContractAddress) -> felt252;

    fn is_user_undercollateralized(self: @TContractState, user: ContractAddress) -> bool;

    fn is_collateral_enabled(
        self: @TContractState, user: ContractAddress, token: ContractAddress
    ) -> bool;

    fn get_last_call_result(self: @TContractState) -> felt252;

    //
    // External
    //

    fn set_lending_accumulator(ref self: TContractState, token: ContractAddress, value: felt252);

    fn set_debt_accumulator(ref self: TContractState, token: ContractAddress, value: felt252);

    fn set_user_undercollateralized(ref self: TContractState, user: ContractAddress, value: bool);

    fn mint_z_token(
        ref self: TContractState, z_token: ContractAddress, to: ContractAddress, amount: felt252
    );

    fn burn_all_z_token(ref self: TContractState, z_token: ContractAddress, user: ContractAddress);
}

#[starknet::interface]
trait IMockPriceOracle<TContractState> {
    //
    // External
    //

    fn set_price(
        ref self: TContractState, token: ContractAddress, price: felt252, update_time: felt252
    );
}

#[starknet::interface]
trait IMockPragmaOracle<TContractState> {
    //
    // External
    //

    fn set_price(
        ref self: TContractState,
        pair_id: felt252,
        price: felt252,
        decimals: felt252,
        last_updated_timestamp: felt252,
        num_sources_aggregated: felt252
    );
}

#[starknet::interface]
trait IFlashLoanHandler<TContractState> {
    //
    // External
    //

    fn take_flash_loan(
        ref self: TContractState,
        market_addr: ContractAddress,
        token: ContractAddress,
        amount: felt252,
        return_amount: felt252
    );
}
