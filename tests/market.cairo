use option::OptionTrait;
use test::test_utils::assert_eq;
use traits::{Into, TryInto};

use starknet::contract_address_const;

use zklend::interfaces::{
    IInterestRateModelDispatcher, IMarketDispatcher, IMarketDispatcherTrait, IZTokenDispatcher,
    IZTokenDispatcherTrait
};
use zklend::market::Market;

use tests::assertions::{assert_approximatedly_equals, assert_event_emitted};
use tests::{deploy, event_keys};
use tests::mock::{
    IAccountDispatcher, IAccountDispatcherTrait, IERC20Dispatcher, IERC20DispatcherTrait,
    IFlashLoanHandlerDispatcherTrait, IMockPriceOracleDispatcher, IMockPriceOracleDispatcherTrait
};

// TODO: add test cases for:
// - rate changes after calling `withdraw_all` when there're aother debt & deposit holders
// - rate changes after calling `repay_all` when there're aother debt & deposit holders

const MOCK_TREASURY_ADDRESS: felt252 = 9999888899998888;

#[derive(Drop)]
struct Setup {
    alice: IAccountDispatcher,
    bob: IAccountDispatcher,
    oracle: IMockPriceOracleDispatcher,
    market: IMarketDispatcher,
    token_a: IERC20Dispatcher,
    z_token_a: IZTokenDispatcher,
    irm_a: IInterestRateModelDispatcher,
    token_b: IERC20Dispatcher,
    z_token_b: IZTokenDispatcher,
    irm_b: IInterestRateModelDispatcher
}

fn pre_setup() -> Setup {
    let alice = deploy::deploy_account(1);
    let bob = deploy::deploy_account(2);

    let oracle = deploy::deploy_mock_price_oracle();

    let market = deploy::deploy_market(alice.contract_address, oracle.contract_address);

    let token_a = deploy::deploy_erc20(
        'Test Token A', // name
        'TST_A', // symbol
        18, // decimals
        1000000000000000000000000, // initial_supply
        alice.contract_address // recipient
    );
    let z_token_a = deploy::deploy_z_token(
        contract_address_const::<999999>(), // owner
        market.contract_address, // market
        token_a.contract_address, // underlying
        'zkLend Interest-Bearing TST_A', // name
        'zTST_A', // symbol
        18 // decimals
    );
    let irm_a = deploy::deploy_default_interest_rate_model(
        100000000000000000000000000, // slope_0: 0.1
        500000000000000000000000000, // slope_1: 0.5
        10000000000000000000000000, // y_intercept: 1%
        600000000000000000000000000 // optimal_rate: 60%
    );

    let token_b = deploy::deploy_erc20(
        'Test Token B', // name
        'TST_B', // symbol
        18, // decimals
        1000000000000000000000000, // initial_supply
        bob.contract_address // recipient
    );
    let z_token_b = deploy::deploy_z_token(
        contract_address_const::<999999>(), // owner
        market.contract_address, // market
        token_b.contract_address, // underlying
        'zkLend Interest-Bearing TST_B', // name
        'zTST_B', // symbol
        18 // decimals
    );
    let irm_b = deploy::deploy_default_interest_rate_model(
        200000000000000000000000000, // slope_0: 0.2
        300000000000000000000000000, // slope_1: 0.3
        50000000000000000000000000, // y_intercept: 5%
        800000000000000000000000000, // optimal_rate: 80%
    );

    Setup { alice, bob, oracle, market, token_a, z_token_a, irm_a, token_b, z_token_b, irm_b }
}

fn setup() -> Setup {
    let setup = pre_setup();

    // TST_A: 50% collateral_factor, 80% borrow_factor
    // TST_B: 75% collateral_factor, 90% borrow_factor
    setup
        .alice
        .market_set_treasury(
            setup.market.contract_address, MOCK_TREASURY_ADDRESS.try_into().unwrap()
        );
    setup
        .alice
        .market_add_reserve(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            setup.z_token_a.contract_address, // z_token
            setup.irm_a.contract_address, // interest_rate_model
            500000000000000000000000000, // collateral_factor
            800000000000000000000000000, // borrow_factor
            100000000000000000000000000, // reserve_factor
            50000000000000000000000000, // flash_loan_fee
            200000000000000000000000000, // liquidation_bonus
        );
    setup
        .alice
        .market_add_reserve(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            setup.z_token_b.contract_address, // z_token
            setup.irm_b.contract_address, // interest_rate_model
            750000000000000000000000000, // collateral_factor
            900000000000000000000000000, // borrow_factor
            200000000000000000000000000, // reserve_factor
            10000000000000000000000000, // flash_loan_fee
            100000000000000000000000000, // liquidation_bonus
        );

    setup
        .alice
        .market_set_debt_limit(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            999999999999999999999999999999 // limit
        );
    setup
        .alice
        .market_set_debt_limit(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            999999999999999999999999999999 // limit
        );

    setup
        .oracle
        .set_price(
            setup.token_a.contract_address, // token
             50_00000000, // price
             100 // update_time
        );
    setup
        .oracle
        .set_price(
            setup.token_b.contract_address, // token
             100_00000000, // price
             100 // update_time
        );

    setup
}

fn setup_with_alice_deposit() -> Setup {
    let setup = setup();

    setup
        .alice
        .erc20_approve(
            setup.token_a.contract_address,
            setup.market.contract_address, // spender
            100000000000000000000 // amount
        );
    setup
        .alice
        .market_deposit(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            100000000000000000000 // amount
        );
    setup
        .alice
        .market_enable_collateral(setup.market.contract_address, setup.token_a.contract_address);

    setup
}

fn setup_with_alice_and_bob_deposit() -> Setup {
    let setup = setup_with_alice_deposit();

    setup
        .bob
        .erc20_approve(
            setup.token_b.contract_address,
            setup.market.contract_address, // spender
            1000000000000000000000000 // amount
        );
    setup
        .bob
        .market_deposit(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            10000000000000000000000 // amount
        );
    setup
        .bob
        .market_enable_collateral(setup.market.contract_address, setup.token_b.contract_address);

    setup
}

fn setup_with_loan() -> Setup {
    let setup = setup_with_alice_and_bob_deposit();

    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            22500000000000000000 // amount
        );

    setup
}

#[test]
#[available_gas(90000000)]
fn test_new_reserve_event() {
    let setup = pre_setup();

    setup
        .alice
        .market_add_reserve(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            setup.z_token_a.contract_address, // z_token
            setup.irm_a.contract_address, // interest_rate_model
            500000000000000000000000000, // collateral_factor
            800000000000000000000000000, // borrow_factor
            100000000000000000000000000, // reserve_factor
            50000000000000000000000000, // flash_loan_fee
            200000000000000000000000000 // liquidation_bonus
        );

    assert_event_emitted(
        setup.market.contract_address,
        event_keys::NEW_RESERVE,
        @Market::NewReserve {
            token: setup.token_a.contract_address,
            z_token: setup.z_token_a.contract_address,
            decimals: 18,
            interest_rate_model: setup.irm_a.contract_address,
            collateral_factor: 500000000000000000000000000,
            borrow_factor: 800000000000000000000000000,
            reserve_factor: 100000000000000000000000000,
            flash_loan_fee: 50000000000000000000000000,
            liquidation_bonus: 200000000000000000000000000
        }
    );
}

// Context: there was a bug in commit 98cc54b that incorrectly enables collateral usage when calling
// the disable function on an already-disabled collteral.
#[test]
#[available_gas(90000000)]
fn test_disabling_already_disabled_collateral() {
    let setup = setup();

    // 1 << 0 * 2
    let slot: u256 = 1;

    // Token is disabled as collateral by default
    assert_eq(
        @BitAnd::bitand(setup.market.get_user_flags(setup.alice.contract_address).into(), slot),
        @0,
        'FAILED'
    );

    setup
        .alice
        .market_disable_collateral(setup.market.contract_address, setup.token_a.contract_address);

    // Token should still be disabled
    assert_eq(
        @BitAnd::bitand(setup.market.get_user_flags(setup.alice.contract_address).into(), slot),
        @0,
        'FAILED'
    );
}

#[test]
#[available_gas(90000000)]
fn test_token_transferred_on_deposit() {
    let setup = setup();

    setup
        .alice
        .erc20_approve(
            setup.token_a.contract_address,
            setup.market.contract_address, // spender
            1000000000000000000 // amount
        );
    setup
        .alice
        .market_deposit(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            1000000000000000000 // amount
        );
    setup
        .alice
        .market_enable_collateral(setup.market.contract_address, setup.token_a.contract_address);

    assert_eq(
        @setup.token_a.balanceOf(setup.alice.contract_address), @999999000000000000000000, 'FAILED'
    );
    assert_eq(
        @setup.token_a.balanceOf(setup.market.contract_address), @1000000000000000000, 'FAILED'
    );

    assert_eq(
        @setup.z_token_a.balanceOf(setup.alice.contract_address), @1000000000000000000, 'FAILED'
    );
    assert_eq(@setup.z_token_a.totalSupply(), @1000000000000000000, 'FAILED');

    // 1 << 0 * 2
    let slot: u256 = 1;

    // Token is set as collateral by default
    assert_eq(
        @BitAnd::bitand(setup.market.get_user_flags(setup.alice.contract_address).into(), slot),
        @1,
        'FAILED'
    );
}

#[test]
#[available_gas(90000000)]
#[should_panic(
    expected: (
        'ERC20_INSUFFICIENT_ALLOWANCE',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED',
        'ENTRYPOINT_FAILED'
    )
)]
fn test_deposit_transfer_failed() {
    let setup = setup();

    // transferFrom fails due to insufficient allowance
    setup
        .alice
        .market_deposit(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            1000000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_ZERO_AMOUNT', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_cannot_withdraw_with_zero_amount() {
    let setup = setup_with_alice_deposit();

    setup
        .alice
        .market_withdraw(
            setup.market.contract_address, setup.token_a.contract_address, // token
             0 // amount
        );
}

#[test]
#[available_gas(90000000)]
fn test_token_burnt_on_withdrawal() {
    let setup = setup_with_alice_deposit();

    // Alice: 999,900 TST_A, 100 zTST_A
    assert_eq(
        @setup.token_a.balanceOf(setup.alice.contract_address), @999900000000000000000000, 'FAILED'
    );
    assert_eq(
        @setup.z_token_a.balanceOf(setup.alice.contract_address), @100000000000000000000, 'FAILED'
    );

    setup
        .alice
        .market_withdraw(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            25000000000000000000 // amount
        );

    // Alice: 999,925 TST_A, 75 zTST_A
    assert_eq(
        @setup.token_a.balanceOf(setup.alice.contract_address), @999925000000000000000000, 'FAILED'
    );
    assert_eq(
        @setup.z_token_a.balanceOf(setup.alice.contract_address), @75000000000000000000, 'FAILED'
    );

    setup.alice.market_withdraw_all(setup.market.contract_address, setup.token_a.contract_address);

    // Alice: 1,000,000 TST_A, 0 zTST_A
    assert_eq(
        @setup.token_a.balanceOf(setup.alice.contract_address), @1000000000000000000000000, 'FAILED'
    );
    assert_eq(@setup.z_token_a.balanceOf(setup.alice.contract_address), @0, 'FAILED');
}

#[test]
#[available_gas(90000000)]
fn test_has_debt_flag_changed_on_borrow() {
    let setup = setup_with_alice_and_bob_deposit();

    // Debt flag not set before borrowing
    assert_eq(@setup.market.user_has_debt(setup.alice.contract_address), @false, 'FAILED');

    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            22500000000000000000 // amount
        );

    // Debt flag set after borrowing
    assert_eq(@setup.market.user_has_debt(setup.alice.contract_address), @true, 'FAILED');
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_INSUFFICIENT_COLLATERAL', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_cannot_borrow_more_than_capacity() {
    let setup = setup_with_alice_and_bob_deposit();

    // TST_A collteral: 100 TST_A * 0.5 = 2,500 USD
    // For borrowing TST_B: 2,500 * 0.9 = 2,250 USD
    // Maximum borrow: 22.5 TST_B
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            22600000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
fn test_token_received_on_borrow() {
    let setup = setup_with_loan();

    assert_eq(
        @setup.token_b.balanceOf(setup.alice.contract_address), @22500000000000000000, 'FAILED'
    );
}

#[test]
#[available_gas(90000000)]
fn test_rates_changed_on_borrow() {
    let setup = setup_with_loan();

    // Borrowing rate:
    //   Utilization rate = 22.5 / 10,000 = 0.00225
    //   Borrowing rate = 0.05 + 0.2 * 0.00225 / 0.8 = 0.0505625 => 505625 * 10 ** 20
    // Lending rate:
    //   Lending rate = 0.0505625 * 0.00225 = 0.000113765625 => 113765625 * 10 ** 15
    let reserve_data = setup.market.get_reserve_data(setup.token_b.contract_address);
    assert_eq(@reserve_data.current_lending_rate, @113765625000000000000000, 'FAILED');
    assert_eq(@reserve_data.current_borrowing_rate, @50562500000000000000000000, 'FAILED');
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_INSUFFICIENT_COLLATERAL', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_collateral_used_by_existing_loan() {
    let setup = setup_with_loan();

    // Cannot borrow anymore with existing collateral
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            22500000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_INSUFFICIENT_COLLATERAL', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_cannot_withdraw_collateral_used_by_loan() {
    let setup = setup_with_loan();

    setup
        .alice
        .market_withdraw(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            10000000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
#[should_panic(
    expected: ('ZT_INVALID_COLLATERALIZATION', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED')
)]
fn test_cannot_transfer_collateral_used_by_loan() {
    let setup = setup_with_loan();

    setup
        .alice
        .erc20_transfer(
            setup.z_token_a.contract_address,
            setup.token_a.contract_address, // recipient
            10000000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
fn test_can_borrow_again_with_more_collateral() {
    let setup = setup_with_loan();

    // Alice borrows more with more collateral
    setup
        .alice
        .erc20_approve(
            setup.token_a.contract_address,
            setup.market.contract_address, // spender
            100000000000000000000 // amount
        );
    setup
        .alice
        .market_deposit(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            100000000000000000000 // amount
        );
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            22500000000000000000 // amount
        );

    assert_eq(
        @setup.token_b.balanceOf(setup.alice.contract_address), @45000000000000000000, 'FAILED'
    );

    // Borrowing rate:
    //   Utilization rate = 45 / 10,000 = 0.0045
    //   Borrowing rate = 0.05 + 0.2 * 0.0045 / 0.8 = 0.051125 => 51125 * 10 ** 21
    // Lending rate:
    //   Lending rate = 0.051125 * 0.0045 = 0.0002300625 => 2300625 * 10 ** 17
    let reserve_data = setup.market.get_reserve_data(setup.token_b.contract_address);
    assert_eq(@reserve_data.current_lending_rate, @230062500000000000000000, 'FAILED');
    assert_eq(@reserve_data.current_borrowing_rate, @51125000000000000000000000, 'FAILED');
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_DEBT_LIMIT_EXCEEDED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_borrow_cannot_exceed_debt_limit() {
    let setup = setup_with_alice_and_bob_deposit();

    // Debt limit set to 10 TST_B
    setup
        .alice
        .market_set_debt_limit(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            10000000000000000000 // limit
        );

    // Alice can't borrow 11 TST_B
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            11000000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
fn test_can_borrow_till_debt_limit() {
    let setup = setup_with_alice_and_bob_deposit();

    // Debt limit set to 10 TST_B
    setup
        .alice
        .market_set_debt_limit(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            10000000000000000000 // limit
        );

    // Borrowing 10 TST_B is allowed (exactly at limit)
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            10000000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_DEBT_LIMIT_EXCEEDED', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_debt_limit_is_global() {
    let setup = setup_with_alice_and_bob_deposit();

    // Debt limit set to 10 TST_B
    setup
        .alice
        .market_set_debt_limit(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            10000000000000000000 // limit
        );

    // The full limit is used by Alice
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            10000000000000000000 // amount
        );

    // Bob cannot borrow anymore as the limit is global
    setup
        .bob
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            1000000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
fn test_rate_changes_on_deposit() {
    let setup = setup_with_loan();

    // Bob deposits another 5,000 TST_B
    setup
        .bob
        .market_deposit(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            5000000000000000000000 // amount
        );

    // Borrowing rate:
    //   Utilization rate = 22.5 / 15,000 = 0.0015
    //   Borrowing rate = 0.05 + 0.2 * 0.0015 / 0.8 = 0.050375 => 50375 * 10 ** 21
    // Lending rate:
    //   Lending rate = 0.050375 * 0.0015 = 0.0000755625 => 755625 * 10 ** 17
    let reserve_data = setup.market.get_reserve_data(setup.token_b.contract_address);
    assert_eq(@reserve_data.current_lending_rate, @75562500000000000000000, 'FAILED');
    assert_eq(@reserve_data.current_borrowing_rate, @50375000000000000000000000, 'FAILED');
}

#[test]
#[available_gas(90000000)]
fn test_rate_changes_on_withdrawal() {
    let setup = setup_with_loan();

    // Bob withdraws 5,000 TST_B
    setup
        .bob
        .market_withdraw(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            5000000000000000000000 // amount
        );

    // Borrowing rate:
    //   Utilization rate = 22.5 / 5,000 = 0.0045
    //   Borrowing rate = 0.05 + 0.2 * 0.0045 / 0.8 = 0.051125 => 51125 * 10 ** 21
    // Lending rate:
    //   Lending rate = 0.051125 * 0.0045 = 0.0002300625 => 2300625 * 10 ** 17
    let reserve_data = setup.market.get_reserve_data(setup.token_b.contract_address);
    assert_eq(@reserve_data.current_lending_rate, @230062500000000000000000, 'FAILED');
    assert_eq(@reserve_data.current_borrowing_rate, @51125000000000000000000000, 'FAILED');
}

// TODO: test treasury balance
#[test]
#[available_gas(90000000)]
fn test_interest_accumulation() {
    let setup = setup_with_loan();

    // No interest accumulated yet
    assert_eq(
        @setup.z_token_b.balanceOf(setup.bob.contract_address), @10000000000000000000000, 'FAILED'
    );

    starknet::testing::set_block_timestamp(100);

    // Interest after 100 seconds:
    //   Interest = 0.000113765625 * 10000 * 100 * (1 - 20%) / (365 * 86400) = 0.000002885987442922374429223
    //                                                         => 2885987442922
    //   Total balance = 10000 * 10 ** 18 + 2885987442922
    assert_eq(
        @setup.z_token_b.balanceOf(setup.bob.contract_address), @10000000002885987442922, 'FAILED'
    );
}

#[test]
#[available_gas(90000000)]
fn test_debt_accumulation() {
    let setup = setup_with_loan();

    // No interest accumulated yet
    assert_eq(
        @setup
            .market
            .get_user_debt_for_token(setup.alice.contract_address, setup.token_b.contract_address),
        @22500000000000000000,
        'FAILED'
    );

    starknet::testing::set_block_timestamp(100);

    // Interest after 100 seconds:
    //   Interest = 0.0505625 * 22.5 * 100 / (365 * 86400) = 0.000003607484303652968036529
    //                                                   => 3607484303652
    //   Total debt = 22.5 * 10 ** 18 + 3607484303652
    assert_eq(
        @setup
            .market
            .get_user_debt_for_token(setup.alice.contract_address, setup.token_b.contract_address),
        @22500003607484303652,
        'FAILED'
    );
    assert_eq(
        @setup.market.get_total_debt_for_token(setup.token_b.contract_address),
        @22500003607484303652,
        'FAILED'
    );
}

#[test]
#[available_gas(90000000)]
fn test_repay_all_with_interest() {
    let setup = setup_with_loan();

    starknet::testing::set_block_timestamp(100);

    // Same as `test_debt_accumulation`
    // Total debt = 22.500003607484303652 TST_B

    setup
        .bob
        .erc20_transfer(
            setup.token_b.contract_address,
            setup.alice.contract_address, // recipient
            1000000000000000000 // amount
        );

    setup
        .alice
        .erc20_approve(
            setup.token_b.contract_address,
            setup.market.contract_address, // spender
            23000000000000000000 // amount
        );
    setup
        .alice
        .market_repay_all(setup.market.contract_address, setup.token_b.contract_address // token
        );

    // Alice TST_B balance:
    //   22.5 + 1 - 22.500003607484303652 = 0.999996392515696348
    assert_eq(
        @setup.token_b.balanceOf(setup.alice.contract_address), @999996392515696348, 'FAILED'
    );

    // No more debt in system
    assert_eq(
        @setup
            .market
            .get_user_debt_for_token(setup.alice.contract_address, setup.token_b.contract_address),
        @0,
        'FAILED'
    );
    assert_eq(@setup.market.get_total_debt_for_token(setup.token_b.contract_address), @0, 'FAILED');

    // No more debt accumulation

    starknet::testing::set_block_timestamp(200);

    assert_eq(
        @setup
            .market
            .get_user_debt_for_token(setup.alice.contract_address, setup.token_b.contract_address),
        @0,
        'FAILED'
    );
    assert_eq(@setup.market.get_total_debt_for_token(setup.token_b.contract_address), @0, 'FAILED');
}

#[test]
#[available_gas(90000000)]
fn test_no_debt_accumulation_without_loan() {
    let setup = setup();

    // Alice deposits token A
    setup
        .alice
        .erc20_approve(
            setup.token_a.contract_address,
            setup.market.contract_address, // spender
            1000000000000000000000000 // amount
        );
    setup
        .alice
        .market_deposit(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            10000000000000000000000 // amount
        );
    setup
        .alice
        .market_enable_collateral(setup.market.contract_address, setup.token_a.contract_address);

    /// No interest accumulated yet
    assert_eq(
        @setup.market.get_debt_accumulator(setup.token_a.contract_address),
        @1000000000000000000000000000,
        'FAILED'
    );

    starknet::testing::set_block_timestamp(100);

    // Still no accumulation after 100 seconds

    assert_eq(
        @setup.market.get_debt_accumulator(setup.token_a.contract_address),
        @1000000000000000000000000000,
        'FAILED'
    );
}

#[test]
#[available_gas(90000000)]
fn test_debt_repayment() {
    let setup = setup_with_loan();

    // Total debt is 22.500003607484303652 (based on `test_debt_accumulation`)
    starknet::testing::set_block_timestamp(100);

    // Alice repays 1 TST_B
    setup
        .alice
        .erc20_approve(
            setup.token_b.contract_address,
            setup.market.contract_address, // spender
            1000000000000000000 // amount
        );
    setup
        .alice
        .market_repay(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            1000000000000000000 // amount
        );

    // Off by one due to rounding error
    //   Expected: 21500003607484303652
    //   Actual  : 21500003607484303653
    assert_eq(
        @setup
            .market
            .get_user_debt_for_token(setup.alice.contract_address, setup.token_b.contract_address),
        @21500003607484303653,
        'FAILED'
    );
    assert_eq(
        @setup.market.get_total_debt_for_token(setup.token_b.contract_address),
        @21500003607484303653,
        'FAILED'
    );
    assert_eq(
        @setup.token_b.balanceOf(setup.alice.contract_address), @21500000000000000000, 'FAILED'
    );
    assert_eq(
        @setup.token_b.balanceOf(setup.market.contract_address), @9978500000000000000000, 'FAILED'
    );

    // Interest rates after repayment
    //   Borrowing rate:
    //     Utilization rate = 21.500003607484303653 / 10,000.000003607484303653
    //                      = 0.002150000359972821110154974
    //     Borrowing rate = 0.05 + 0.2 * 0.002150000359972821110154974 / 0.8
    //                    = 0.050537500089993205277538743
    //   Lending rate:
    //     Lending rate = 0.050537500089993205277538743 * 0.002150000359972821110154974
    //                  = 0.000108655643385611870596273
    let reserve_data = setup.market.get_reserve_data(setup.token_b.contract_address);
    assert_eq(@reserve_data.current_lending_rate, @108655643385611870596273, 'FAILED');
    assert_eq(@reserve_data.current_borrowing_rate, @50537500089993205277538743, 'FAILED');
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_INVALID_LIQUIDATION', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_cannot_liquidate_healthy_positions() {
    let setup = setup_with_loan();

    // Alice status now:
    //   Collateral value:
    //     100 TST_A
    //       = 100 * 50 * 0.5
    //       = 2500 USD
    //   Collateral required:
    //     22.5 TST_B
    //       = 22.5 * 100
    //       = 2250 USD

    // TST_A price changes to 45 USD
    //   Collateral value:
    //     100 TST_A
    //       = 100 * 45 * 0.5
    //       = 2250 USD
    setup
        .oracle
        .set_price(
            setup.token_a.contract_address, // token
             45_00000000, // price
             100 // update_time
        );

    // Cannot liquidate now as Alice is not undercollateralized
    setup
        .bob
        .market_liquidate(
            setup.market.contract_address,
            setup.alice.contract_address, // user
            setup.token_b.contract_address, // debt_token
            1000000000000000000, // amount
            setup.token_a.contract_address // collateral_token
        );
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_INVALID_LIQUIDATION', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_cannot_liquidate_too_much() {
    let setup = setup_with_loan();

    // Alice status now:
    //   Collateral value:
    //     100 TST_A
    //       = 100 * 50 * 0.5
    //       = 2500 USD
    //   Collateral required:
    //     22.5 TST_B
    //       = 22.5 * 100
    //       = 2250 USD

    // Change TST_A price to 40 USD
    //   Collateral value:
    //     100 TST_A
    //       = 100 * 40 * 0.5
    //       = 2000 USD
    //   Collateral required: 2250 USD
    setup
        .oracle
        .set_price(
            setup.token_a.contract_address, // token
             40_00000000, // price
             100 // update_time
        );

    // Repay maximum x TST_B:
    //   Collateral withdrawn:
    //     x * 100 / 40 * 1.2 TST_A
    //   Collateral value after:
    //     (100 - x * 100 / 40 * 1.2) TST_A
    //       = (100 - x * 100 / 40 * 1.2) * 40 * 0.5
    //   Collateral required:
    //     (22.5 - x) TST_B
    //       = (22.5 - x) * 100
    //   Collateral value after = Collateral required
    //     Solve for x
    //       x = 6.25

    // Liquidating 6.26 TST_B is not allowed as it exceeds maximum
    setup
        .bob
        .market_liquidate(
            setup.market.contract_address,
            setup.alice.contract_address, // user
            setup.token_b.contract_address, // debt_token
            6260000000000000000, // amount
            setup.token_a.contract_address // collateral_token
        );
}

#[test]
#[available_gas(90000000)]
fn test_liquidation() {
    let setup = setup_with_loan();

    // Alice status now:
    //   Collateral value:
    //     100 TST_A
    //       = 100 * 50 * 0.5
    //       = 2500 USD
    //   Collateral required:
    //     22.5 TST_B
    //       = 22.5 * 100
    //       = 2250 USD

    // Change TST_A price to 40 USD
    //   Collateral value:
    //     100 TST_A
    //       = 100 * 40 * 0.5
    //       = 2000 USD
    //   Collateral required: 2250 USD
    setup
        .oracle
        .set_price(
            setup.token_a.contract_address, // token
             40_00000000, // price
             100, // update_time
        );

    // Liquidating 6.25 TST_B works
    setup
        .bob
        .market_liquidate(
            setup.market.contract_address,
            setup.alice.contract_address, // user
            setup.token_b.contract_address, // debt_token
            6250000000000000000, // amount
            setup.token_a.contract_address // collateral_token
        );

    // Bob balances after:
    //   TST_A (Z):
    //     6.25 * 100 / 40 * 1.2 = 18.75 TST_A
    //   TST_B:
    //     1,000,000 - 10,000 - 6.25 = 989,993.75 TST_B
    assert_eq(
        @setup.z_token_a.balanceOf(setup.bob.contract_address), @18750000000000000000, 'FAILED'
    );
    assert_eq(
        @setup.token_b.balanceOf(setup.bob.contract_address), @989993750000000000000000, 'FAILED'
    );

    // Alice:
    //   Debt:
    //     22.5 - 6.25 = 16.25 TST_B
    //   TST_A (Z):
    //     100 - 18.75 = 81.25 TST_A
    assert_eq(
        @setup
            .market
            .get_user_debt_for_token(setup.alice.contract_address, setup.token_b.contract_address),
        @16250000000000000000,
        'FAILED'
    );
    assert_eq(
        @setup.market.get_total_debt_for_token(setup.token_b.contract_address),
        @16250000000000000000,
        'FAILED'
    );
    assert_eq(
        @setup.z_token_a.balanceOf(setup.alice.contract_address), @81250000000000000000, 'FAILED'
    );
}

#[test]
#[available_gas(90000000)]
fn test_event_emission() {
    let setup = setup();

    setup
        .alice
        .erc20_approve(
            setup.token_a.contract_address,
            setup.market.contract_address, // spender
            100000000000000000000 // amount
        );

    // Deposit emits the events
    setup
        .alice
        .market_deposit(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            100000000000000000000 // amount
        );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::ACCUMULATORS_SYNC,
        @Market::AccumulatorsSync {
            token: setup.token_a.contract_address,
            lending_accumulator: 1000000000000000000000000000,
            debt_accumulator: 1000000000000000000000000000
        }
    );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::DEPOSIT,
        @Market::Deposit {
            user: setup.alice.contract_address,
            token: setup.token_a.contract_address,
            face_amount: 100000000000000000000
        }
    );

    // 100 seconds passed
    starknet::testing::set_block_timestamp(100);

    // Bob deposits 10,000 TST_B so that Alice can borrow.
    // Accumulators unchanged
    setup
        .bob
        .erc20_approve(
            setup.token_b.contract_address,
            setup.market.contract_address, // spender
            1000000000000000000000000 // amount
        );
    setup
        .bob
        .market_deposit(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            10000000000000000000000 // amount
        );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::ACCUMULATORS_SYNC,
        @Market::AccumulatorsSync {
            token: setup.token_b.contract_address,
            lending_accumulator: 1000000000000000000000000000,
            debt_accumulator: 1000000000000000000000000000
        }
    );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::DEPOSIT,
        @Market::Deposit {
            user: setup.bob.contract_address,
            token: setup.token_b.contract_address,
            face_amount: 10000000000000000000000
        }
    );

    // 100 seconds passed
    starknet::testing::set_block_timestamp(200);

    // Alice borrows 22.5 TST_B
    // Accumulators unchanged
    setup
        .alice
        .market_enable_collateral(setup.market.contract_address, setup.token_a.contract_address);
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            22500000000000000000 // amount
        );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::ACCUMULATORS_SYNC,
        @Market::AccumulatorsSync {
            token: setup.token_b.contract_address,
            lending_accumulator: 1000000000000000000000000000,
            debt_accumulator: 1000000000000000000000000000
        }
    );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::BORROWING,
        @Market::Borrowing {
            user: setup.alice.contract_address,
            token: setup.token_b.contract_address,
            raw_amount: 22500000000000000000,
            face_amount: 22500000000000000000
        }
    );

    // 100 seconds passed
    starknet::testing::set_block_timestamp(300);

    // Accumulations:
    //   Interest rate (see `test_borrow_token`):
    //     Borrowing rate = 0.0505625
    //     Lending rate = 0.000113765625
    //   Lending accmulator:
    //     1 * (1 + (100 * 0.000113765625 * (1 - 20%)) / (365 * 86400)) = 1.000000000288598744292237442
    //   Debt accmulator:
    //     1 * (1 + (100 * 0.0505625) / (365 * 86400)) = 1.000000160332635717909690512

    // Alice repays 1 TST_B
    //   Raw amount repaid:
    //     1 / 1.000000160332635717909690512 = 0.999999839667389988
    setup
        .alice
        .erc20_approve(
            setup.token_b.contract_address,
            setup.market.contract_address, // spender
            1000000000000000000 // amount
        );
    setup
        .alice
        .market_repay(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            1000000000000000000 // amount
        );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::ACCUMULATORS_SYNC,
        @Market::AccumulatorsSync {
            token: setup.token_b.contract_address,
            lending_accumulator: 1000000000288598744292237442,
            debt_accumulator: 1000000160332635717909690512
        }
    );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::REPAYMENT,
        @Market::Repayment {
            repayer: setup.alice.contract_address,
            beneficiary: setup.alice.contract_address,
            token: setup.token_b.contract_address,
            raw_amount: 999999839667389988,
            face_amount: 1000000000000000000
        }
    );

    // 100 seconds passed
    starknet::testing::set_block_timestamp(400);

    // Accumulations:
    //   Interest rate (see `test_debt_repayment`):
    //     Borrowing rate = 0.050537500089993205277538743
    //     Lending rate = 0.000108655643385611870596273
    //   Lending accmulator:
    //     1.000000000288598744292237442 * (1 + (100 * 0.000108655643385611870596273 * (1 - 20%)) / (365 * 86400))
    //     = 1.000000000564234572341374307
    //   Debt accmulator:
    //     1.000000160332635717909690512 * (1 + (100 * 0.050537500089993205277538743) / (365 * 86400))
    //     = 1.000000320586022935070387176

    // Bob withdraws 5,000 TST_B
    setup
        .bob
        .market_withdraw(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            5000000000000000000000 // amount
        );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::ACCUMULATORS_SYNC,
        @Market::AccumulatorsSync {
            token: setup.token_b.contract_address,
            lending_accumulator: 1000000000564234572341374307,
            debt_accumulator: 1000000320586022935070387176
        }
    );
    assert_event_emitted(
        setup.market.contract_address,
        event_keys::WITHDRAWAL,
        @Market::Withdrawal {
            user: setup.bob.contract_address,
            token: setup.token_b.contract_address,
            face_amount: 5000000000000000000000
        }
    );
}

#[test]
#[available_gas(90000000)]
fn test_flashloan_succeeds_with_enough_fees() {
    let setup = setup_with_loan();
    let callback = deploy::deploy_flash_loan_handler();

    // Sends enough token to callback contract so that it can return funds
    setup
        .alice
        .erc20_transfer(
            setup.token_a.contract_address,
            callback.contract_address, // recipient
            1000000000000000000000 // amount
        );

    // Returning 1 unit less than required
    callback
        .take_flash_loan(
            setup.market.contract_address, // market_addr
            setup.token_a.contract_address, // token
            100000000000000000000, // amount
            105000000000000000000 // return_amount
        );
}

#[test]
#[available_gas(90000000)]
#[should_panic(
    expected: ('MKT_INSUFFICIENT_AMOUNT_REPAID', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED')
)]
fn test_flashloan_fails_without_enough_fees() {
    let setup = setup_with_loan();
    let callback = deploy::deploy_flash_loan_handler();

    // Sends enough token to callback contract so that it can return funds
    setup
        .alice
        .erc20_transfer(
            setup.token_a.contract_address,
            callback.contract_address, // recipient
            1000000000000000000000 // amount
        );

    // Returning just enough fees
    callback
        .take_flash_loan(
            setup.market.contract_address, // market_addr
            setup.token_a.contract_address, // token
            100000000000000000000, // amount
            104999999999999999999 // return_amount
        );
}

// TODO: test scenario with more than one depositor
#[test]
#[available_gas(90000000)]
fn test_flashloan_fee_distribution() {
    let setup = setup_with_loan();
    let callback = deploy::deploy_flash_loan_handler();

    // Sends enough token to callback contract so that it can return funds
    setup
        .bob
        .erc20_transfer(
            setup.token_b.contract_address,
            callback.contract_address, // recipient
            1100000000000000000000 // amount
        );

    // Bob has 10,000 TST_B as collateral now
    assert_eq(
        @setup.z_token_b.balanceOf(setup.bob.contract_address), @10000000000000000000000, 'FAILED'
    );

    // Flashloan pays 100 TST_B as fee
    callback
        .take_flash_loan(
            setup.market.contract_address, // market_addr
            setup.token_b.contract_address, // token
            1000000000000000000000, // amount
            1100000000000000000000 // return_amount
        );

    // Bob should has 10,080 TST_B now as the only depositor
    // (reserve takes 20% of the fees)
    assert_approximatedly_equals(
        setup.z_token_b.balanceOf(setup.bob.contract_address), 10080000000000000000000, 1
    );
    assert_approximatedly_equals(
        setup.z_token_b.balanceOf(MOCK_TREASURY_ADDRESS.try_into().unwrap()),
        20000000000000000000,
        1
    );
    assert_approximatedly_equals(setup.z_token_b.totalSupply(), 10100000000000000000000, 1);

    // Borrowing rate:
    //   Utilization rate = 22.5 / 10,100 = 0.002227722772277227722772277
    //   Borrowing rate = 0.05 + 0.2 * 0.002227722772277227722772277 / 0.8 = 0.050556930693069306930693069 => 50556930693069306930693069
    // Lending rate:
    //   Lending rate = 0.050556930693069306930693069 * 0.002227722772277227722772277 = 0.000112626825801392020390157 => 112626825801392020390157
    let reserve_data = setup.market.get_reserve_data(setup.token_b.contract_address);
    assert_eq(@reserve_data.current_lending_rate, @112626825801392020390157, 'FAILED');
    assert_eq(@reserve_data.current_borrowing_rate, @50556930693069306930693069, 'FAILED');
}

#[test]
#[available_gas(90000000)]
fn test_change_interest_rate_model() {
    let setup = setup_with_loan();

    // (Copied from `test_rates_changed_on_borrow`)
    // Borrowing rate:
    //   Utilization rate = 22.5 / 10,000 = 0.00225
    //   Borrowing rate = 0.05 + 0.2 * 0.00225 / 0.8 = 0.0505625 => 505625 * 10 ** 20
    // Lending rate:
    //   Lending rate = 0.0505625 * 0.00225 = 0.000113765625 => 113765625 * 10 ** 15
    let reserve_data = setup.market.get_reserve_data(setup.token_b.contract_address);
    assert_eq(@reserve_data.current_lending_rate, @113765625000000000000000, 'FAILED');
    assert_eq(@reserve_data.current_borrowing_rate, @50562500000000000000000000, 'FAILED');

    starknet::testing::set_block_timestamp(100);

    // (Copied from `test_interest_accumulation`)
    // Interest after 100 seconds:
    //   Interest = 0.000113765625 * 10000 * 100 * (1 - 20%) / (365 * 86400) = 0.000002885987442922374429223
    //                                                         => 2885987442922
    //   Total balance = 10000 * 10 ** 18 + 2885987442922
    assert_eq(
        @setup.z_token_b.balanceOf(setup.bob.contract_address), @10000000002885987442922, 'FAILED'
    );

    // Change model to have higher interest rate
    let irm_b = deploy::deploy_default_interest_rate_model(
        400000000000000000000000000, // slope_0: 0.4
        300000000000000000000000000, // slope_1: 0.3
        500000000000000000000000000, // y_intercept: 50%
        800000000000000000000000000, // optimal_rate: 80%
    );
    setup
        .alice
        .market_set_interest_rate_model(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            irm_b.contract_address // interest_rate_model
        );

    // Debt interest during 100 seconds:
    //   Interest = 0.0505625 * 22.5 * 100 / (365 * 86400) = 0.000003607484303652

    // New borrowing rate:
    //   Utilization rate = 22.500003607484303652 / 10000.000003607484303652 = 0.002250000359936746267031683
    //   Borrowing rate = 0.5 + 0.4 * 0.002250000359936746267031683 / 0.8 = 0.501125000179968373133515841
    // New lending rate:
    //   Lending rate = 0.501125000179968373133515841 * 0.002250000359936746267031683 = 0.001127531430778230877393893
    let reserve_data = setup.market.get_reserve_data(setup.token_b.contract_address);
    assert_eq(@reserve_data.current_lending_rate, @1127531430778230877393893, 'FAILED');
    assert_eq(@reserve_data.current_borrowing_rate, @501125000179968373133515841, 'FAILED');

    starknet::testing::set_block_timestamp(200);

    // Another 100 seconds (accumulating with the new rate):
    //   Interest = 0.001127531430778230877393893 * 10000.000002885987442922 * 100 * (1 - 20%) / (365 * 86400) = 0.000028603029708362
    //   Total balance = 10000.000002885987442922 + 0.000028603029708362 = 10000.000031489017151284
    assert_eq(
        @setup.z_token_b.balanceOf(setup.bob.contract_address), @10000000031489017151284, 'FAILED'
    );
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_INSUFFICIENT_COLLATERAL', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_change_collateral_factor() {
    let setup = setup_with_alice_and_bob_deposit();

    setup
        .alice
        .market_set_collateral_factor(
            setup.market.contract_address,
            setup.token_a.contract_address, // token
            400000000000000000000000000 // collateral_factor
        );

    // With original collateral factor of 0.5:
    //   TST_A collteral: 100 TST_A * 0.5 = 2,500 USD
    //   For borrowing TST_B: 2,500 * 0.9 = 2,250 USD
    //   Maximum borrow: 22.5 TST_B
    // With updated collateral factor or 0.4:
    //   TST_A collteral: 100 TST_A * 0.4 = 2,000 USD
    //   For borrowing TST_B: 2,000 * 0.9 = 1,800 USD
    //   Maximum borrow: 18 TST_B
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            18100000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
#[should_panic(expected: ('MKT_INSUFFICIENT_COLLATERAL', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED'))]
fn test_change_borrow_factor() {
    let setup = setup_with_alice_and_bob_deposit();

    setup
        .alice
        .market_set_borrow_factor(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            800000000000000000000000000 // borrow_factor
        );

    // With original borrow factor of 0.9:
    //   TST_A collteral: 100 TST_A * 0.5 = 2,500 USD
    //   For borrowing TST_B: 2,500 * 0.9 = 2,250 USD
    //   Maximum borrow: 22.5 TST_B
    // With updated borrow factor of 0.8:
    //   TST_A collteral: 100 TST_A * 0.5 = 2,500 USD
    //   For borrowing TST_B: 2,500 * 0.8 = 2,000 USD
    //   Maximum borrow: 20 TST_B
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            20100000000000000000 // amount
        );
}

#[test]
#[available_gas(90000000)]
fn test_change_reserve_factor() {
    let setup = setup_with_loan();

    // (Copied from `test_rates_changed_on_borrow`)
    // Borrowing rate:
    //   Utilization rate = 22.5 / 10,000 = 0.00225
    //   Borrowing rate = 0.05 + 0.2 * 0.00225 / 0.8 = 0.0505625 => 505625 * 10 ** 20

    starknet::testing::set_block_timestamp(100);

    // Reserve balance is not updated without an actual settlement. We do a noop IRM change here to
    // just for triggering the settlement.
    setup
        .alice
        .market_set_interest_rate_model(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            setup.irm_b.contract_address // interest_rate_model
        );

    // Total interest after 100 seconds:
    //   Interest = 0.0505625 * 22.5 * 100 / (365 * 86400) = 0.000003607484303652
    // Reserve interest:
    //   Interest = 0.000003607484303652 * 20% = 0.000000721496860730
    assert_approximatedly_equals(
        setup.z_token_b.balanceOf(MOCK_TREASURY_ADDRESS.try_into().unwrap()), 721496860730, 1
    );

    // Doubles reserve ratio to 40%
    setup
        .alice
        .market_set_reserve_factor(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            400000000000000000000000000, // reserve_factor
        );

    // Trigger another settlement after 100 seconds
    starknet::testing::set_block_timestamp(200);
    setup
        .alice
        .market_set_interest_rate_model(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            setup.irm_b.contract_address // interest_rate_model
        );

    // Borrowing rate:
    //   Utilization rate = 22.500003607484303652 / 10,000.000003607484303652 = 0.002250000359936746267031683
    //   Borrowing rate = 0.05 + 0.2 * 0.002250000359936746267031683 / 0.8 = 0.050562500089984186566757920
    // New lending rate:
    //   Lending rate = 0.050562500089984186566757920 * 0.002250000359936746267031683 = 0.000113765643401766185290610
    // Total interest after 100 seconds:
    //   Interest = 0.050562500089984186566757920 * 22.500003607484303652 * 100 / (365 * 86400) = 0.000003607484888470
    // Reserve interest:
    //   Interest = 0.000003607484888470 * 40% = 0.000001442993955388
    // Interest on previous reserve balance:
    //   Interest = 0.000113765643401766185290610 * 0.000000721496860730 * 100 / (365 * 86400) * (1 - 40%) = 0.000000000000000156
    // New balance:
    //   Balance = 0.000000721496860730 + 0.000000000000000156 + 0.000001442993955388 = 0.000002164490816274
    assert_approximatedly_equals(
        setup.z_token_b.balanceOf(MOCK_TREASURY_ADDRESS.try_into().unwrap()), 2164490816274, 1
    );
}

#[test]
#[available_gas(90000000)]
fn test_prelisted_token_may_have_price_source_unset() {
    let setup = setup_with_alice_and_bob_deposit();

    let token_c = deploy::deploy_erc20(
        'Test Token C', // name
        'TST_C', // symbol
        18, // decimals
        1000000000000000000000000, // initial_supply
        setup.alice.contract_address // recipient
    );
    let z_token_c = deploy::deploy_z_token(
        contract_address_const::<999999>(), // owner
        setup.market.contract_address, // market
        token_c.contract_address, // underlying
        'zkLend Interest-Bearing TST_C', // name
        'zTST_C', // symbol
        18 // decimals
    );

    // Prelists token C
    setup
        .alice
        .market_add_reserve(
            setup.market.contract_address,
            token_c.contract_address, // token
            z_token_c.contract_address, // z_token
            setup.irm_a.contract_address, // interest_rate_model
            0, // collateral_factor
            1000000000000000000000000000, // borrow_factor
            0, // reserve_factor
            0, // flash_loan_fee
            0, // liquidation_bonus
        );

    // Alice deposits token C and enables collateral
    setup
        .alice
        .erc20_approve(
            token_c.contract_address,
            setup.market.contract_address, // spender
            100000000000000000000 // amount
        );
    setup
        .alice
        .market_deposit(
            setup.market.contract_address,
            token_c.contract_address, // token
            100000000000000000000 // amount
        );
    setup.alice.market_enable_collateral(setup.market.contract_address, token_c.contract_address);

    // Alice borrows. Despite that token C is enabled, the action is allowed even if the oracle
    // would revert upon any price request if made.
    setup
        .alice
        .market_borrow(
            setup.market.contract_address,
            setup.token_b.contract_address, // token
            22500000000000000000 // amount
        );
}
