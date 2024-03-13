mod view;
mod external;
mod internal;
mod traits;
mod errors;
mod storage;

#[starknet::contract]
mod Market {
    use starknet::{ClassHash, ContractAddress};

    // Hack to simulate the `crate` keyword
    use super::super as crate;

    use crate::interfaces::{IMarket, MarketReserveData};

    use super::{external, view};

    #[storage]
    struct Storage {
        oracle: ContractAddress,
        treasury: ContractAddress,
        reserves: LegacyMap::<ContractAddress, MarketReserveData>,
        reserve_count: felt252,
        // index -> token
        reserve_tokens: LegacyMap::<felt252, ContractAddress>,
        // token -> index
        reserve_indices: LegacyMap::<ContractAddress, felt252>,
        /// Bit 0: whether reserve #0 is used as collateral
        /// Bit 1: whether user has debt in reserve #0
        /// Bit 2: whether reserve #1 is used as collateral
        /// Bit 3: whether user has debt in reserve #1
        /// ...
        user_flags: LegacyMap::<ContractAddress, felt252>,
        // (user, token) -> debt
        raw_user_debts: LegacyMap::<(ContractAddress, ContractAddress), felt252>,
        // This weird naming is to maintain backward compatibility with the Cairo 0 version
        Ownable_owner: ContractAddress,
        // Used in `reentrancy_guard`
        entered: bool
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewReserve: NewReserve,
        TreasuryUpdate: TreasuryUpdate,
        AccumulatorsSync: AccumulatorsSync,
        InterestRatesSync: InterestRatesSync,
        InterestRateModelUpdate: InterestRateModelUpdate,
        CollateralFactorUpdate: CollateralFactorUpdate,
        BorrowFactorUpdate: BorrowFactorUpdate,
        DebtLimitUpdate: DebtLimitUpdate,
        Deposit: Deposit,
        Withdrawal: Withdrawal,
        Borrowing: Borrowing,
        Repayment: Repayment,
        Liquidation: Liquidation,
        FlashLoan: FlashLoan,
        CollateralEnabled: CollateralEnabled,
        CollateralDisabled: CollateralDisabled,
        ContractUpgraded: ContractUpgraded,
        OwnershipTransferred: OwnershipTransferred
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct NewReserve {
        token: ContractAddress,
        z_token: ContractAddress,
        decimals: felt252,
        interest_rate_model: ContractAddress,
        collateral_factor: felt252,
        borrow_factor: felt252,
        reserve_factor: felt252,
        flash_loan_fee: felt252,
        liquidation_bonus: felt252,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct TreasuryUpdate {
        new_treasury: ContractAddress
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct AccumulatorsSync {
        token: ContractAddress,
        lending_accumulator: felt252,
        debt_accumulator: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct InterestRatesSync {
        token: ContractAddress,
        lending_rate: felt252,
        borrowing_rate: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct InterestRateModelUpdate {
        token: ContractAddress,
        interest_rate_model: ContractAddress
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct CollateralFactorUpdate {
        token: ContractAddress,
        collateral_factor: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct BorrowFactorUpdate {
        token: ContractAddress,
        borrow_factor: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct DebtLimitUpdate {
        token: ContractAddress,
        limit: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct Deposit {
        user: ContractAddress,
        token: ContractAddress,
        face_amount: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct Withdrawal {
        user: ContractAddress,
        token: ContractAddress,
        face_amount: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct Borrowing {
        user: ContractAddress,
        token: ContractAddress,
        raw_amount: felt252,
        face_amount: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct Repayment {
        repayer: ContractAddress,
        beneficiary: ContractAddress,
        token: ContractAddress,
        raw_amount: felt252,
        face_amount: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct Liquidation {
        liquidator: ContractAddress,
        user: ContractAddress,
        debt_token: ContractAddress,
        debt_raw_amount: felt252,
        debt_face_amount: felt252,
        collateral_token: ContractAddress,
        collateral_amount: felt252,
    }

    /// `fee` indicates the actual fee paid back, which could be higher than the minimum required.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct FlashLoan {
        initiator: ContractAddress,
        receiver: ContractAddress,
        token: ContractAddress,
        amount: felt252,
        fee: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct CollateralEnabled {
        user: ContractAddress,
        token: ContractAddress
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct CollateralDisabled {
        user: ContractAddress,
        token: ContractAddress
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct ContractUpgraded {
        new_class_hash: ClassHash
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, oracle: ContractAddress) {
        external::initializer(ref self, owner, oracle)
    }

    #[external(v0)]
    impl IMarketImpl of IMarket<ContractState> {
        fn get_reserve_data(self: @ContractState, token: ContractAddress) -> MarketReserveData {
            view::get_reserve_data(self, token)
        }

        fn get_lending_accumulator(self: @ContractState, token: ContractAddress) -> felt252 {
            view::get_lending_accumulator(self, token)
        }

        fn get_debt_accumulator(self: @ContractState, token: ContractAddress) -> felt252 {
            view::get_debt_accumulator(self, token)
        }
        // WARN: this must be run BEFORE adjusting the accumulators (otherwise always returns 0)
        fn get_pending_treasury_amount(self: @ContractState, token: ContractAddress) -> felt252 {
            view::get_pending_treasury_amount(self, token)
        }

        fn get_total_debt_for_token(self: @ContractState, token: ContractAddress) -> felt252 {
            view::get_total_debt_for_token(self, token)
        }

        fn get_user_debt_for_token(
            self: @ContractState, user: ContractAddress, token: ContractAddress
        ) -> felt252 {
            view::get_user_debt_for_token(self, user, token)
        }

        /// Returns a bitmap of user flags.
        fn get_user_flags(self: @ContractState, user: ContractAddress) -> felt252 {
            view::get_user_flags(self, user)
        }

        fn is_user_undercollateralized(
            self: @ContractState, user: ContractAddress, apply_borrow_factor: bool
        ) -> bool {
            view::is_user_undercollateralized(self, user, apply_borrow_factor)
        }

        fn is_collateral_enabled(
            self: @ContractState, user: ContractAddress, token: ContractAddress
        ) -> bool {
            view::is_collateral_enabled(self, user, token)
        }

        fn user_has_debt(self: @ContractState, user: ContractAddress) -> bool {
            view::user_has_debt(self, user)
        }

        fn deposit(ref self: ContractState, token: ContractAddress, amount: felt252) {
            external::deposit(ref self, token, amount)
        }

        fn withdraw(ref self: ContractState, token: ContractAddress, amount: felt252) {
            external::withdraw(ref self, token, amount)
        }

        fn withdraw_all(ref self: ContractState, token: ContractAddress) {
            external::withdraw_all(ref self, token)
        }

        fn borrow(ref self: ContractState, token: ContractAddress, amount: felt252) {
            external::borrow(ref self, token, amount)
        }

        fn repay(ref self: ContractState, token: ContractAddress, amount: felt252) {
            external::repay(ref self, token, amount)
        }

        fn repay_for(
            ref self: ContractState,
            token: ContractAddress,
            amount: felt252,
            beneficiary: ContractAddress
        ) {
            external::repay_for(ref self, token, amount, beneficiary)
        }

        fn repay_all(ref self: ContractState, token: ContractAddress) {
            external::repay_all(ref self, token)
        }

        fn enable_collateral(ref self: ContractState, token: ContractAddress) {
            external::enable_collateral(ref self, token)
        }

        fn disable_collateral(ref self: ContractState, token: ContractAddress) {
            external::disable_collateral(ref self, token)
        }

        /// With the current design, liquidators are responsible for calculating the maximum amount allowed.
        /// We simply check collteralization factor is below one after liquidation.
        /// TODO: calculate max amount on-chain because compute is cheap on StarkNet.
        fn liquidate(
            ref self: ContractState,
            user: ContractAddress,
            debt_token: ContractAddress,
            amount: felt252,
            collateral_token: ContractAddress
        ) {
            external::liquidate(ref self, user, debt_token, amount, collateral_token)
        }

        fn flash_loan(
            ref self: ContractState,
            receiver: ContractAddress,
            token: ContractAddress,
            amount: felt252,
            calldata: Span::<felt252>
        ) {
            external::flash_loan(ref self, receiver, token, amount, calldata)
        }

        fn upgrade(ref self: ContractState, new_implementation: ClassHash) {
            external::upgrade(ref self, new_implementation)
        }

        fn add_reserve(
            ref self: ContractState,
            token: ContractAddress,
            z_token: ContractAddress,
            interest_rate_model: ContractAddress,
            collateral_factor: felt252,
            borrow_factor: felt252,
            reserve_factor: felt252,
            flash_loan_fee: felt252,
            liquidation_bonus: felt252
        ) {
            external::add_reserve(
                ref self,
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

        fn set_treasury(ref self: ContractState, new_treasury: ContractAddress) {
            external::set_treasury(ref self, new_treasury)
        }

        fn set_interest_rate_model(
            ref self: ContractState, token: ContractAddress, interest_rate_model: ContractAddress
        ) {
            external::set_interest_rate_model(ref self, token, interest_rate_model)
        }

        fn set_collateral_factor(
            ref self: ContractState, token: ContractAddress, collateral_factor: felt252
        ) {
            external::set_collateral_factor(ref self, token, collateral_factor)
        }

        fn set_borrow_factor(
            ref self: ContractState, token: ContractAddress, borrow_factor: felt252
        ) {
            external::set_borrow_factor(ref self, token, borrow_factor)
        }

        fn set_debt_limit(ref self: ContractState, token: ContractAddress, limit: felt252) {
            external::set_debt_limit(ref self, token, limit)
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            external::transfer_ownership(ref self, new_owner)
        }

        fn renounce_ownership(ref self: ContractState) {
            external::renounce_ownership(ref self)
        }
    }
}
