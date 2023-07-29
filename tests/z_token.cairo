use option::OptionTrait;
use test::test_utils::assert_eq;
use traits::TryInto;

use starknet::{ContractAddress, contract_address_const};

use zklend::interfaces::{IZTokenDispatcher, IZTokenDispatcherTrait};
use zklend::z_token::ZToken;

use tests::{deploy, event_keys};
use tests::assertions::assert_event_emitted;
use tests::mock::{
    IAccountDispatcher, IAccountDispatcherTrait, IMockMarketDispatcher, IMockMarketDispatcherTrait
};

const MOCK_TOKEN_ADDRESS: felt252 = 9999;

#[derive(Drop)]
struct Setup {
    alice: IAccountDispatcher,
    bob: IAccountDispatcher,
    market: IMockMarketDispatcher,
    z_token: IZTokenDispatcher,
}

fn setup() -> Setup {
    let alice = deploy::deploy_account();
    let bob = deploy::deploy_account();

    let market = deploy::deploy_mock_market();

    let z_token = deploy::deploy_z_token(
        contract_address_const::<999999>(), // owner
        market.contract_address, // market
        MOCK_TOKEN_ADDRESS.try_into().unwrap(), // underlying
        'TOKEN_NAME', // name
        'TOKEN_SYMBOL', // symbol
        18 // decimals
    );

    market
        .set_lending_accumulator(
            MOCK_TOKEN_ADDRESS.try_into().unwrap(), // token
             1000000000000000000000000000 // value
        );
    market
        .mint_z_token(
            z_token.contract_address, // z_token
            alice.contract_address, // to
            100000000000000000000 // amount
        );
    market
        .set_lending_accumulator(
            MOCK_TOKEN_ADDRESS.try_into().unwrap(), // token
             2000000000000000000000000000 // value
        );

    Setup { alice, bob, market, z_token }
}

#[test]
#[available_gas(30000000)]
fn test_meta() {
    let setup = setup();

    assert_eq(@setup.z_token.name(), @'TOKEN_NAME', 'FAILED');
    assert_eq(@setup.z_token.symbol(), @'TOKEN_SYMBOL', 'FAILED');
    assert_eq(@setup.z_token.decimals(), @18, 'FAILED');
}

#[test]
#[available_gas(30000000)]
fn test_balance_should_scale_with_accumulator() {
    let setup = setup();

    assert_eq(
        @setup.z_token.balanceOf(setup.alice.contract_address), @200000000000000000000, 'FAILED'
    );
}

#[test]
#[available_gas(30000000)]
fn test_transfer_should_emit_events() {
    let setup = setup();

    setup
        .alice
        .erc20_transfer(
            setup.z_token.contract_address, // contract_address
            setup.bob.contract_address, // recipient
            50000000000000000000 // amount
        );

    assert_event_emitted(
        setup.z_token.contract_address,
        event_keys::TRANSFER,
        @ZToken::Transfer {
            from: setup.alice.contract_address,
            to: setup.bob.contract_address,
            value: 50000000000000000000
        }
    );
    assert_event_emitted(
        setup.z_token.contract_address,
        event_keys::RAW_TRANSFER,
        @ZToken::RawTransfer {
            from: setup.alice.contract_address,
            to: setup.bob.contract_address,
            raw_value: 25000000000000000000,
            accumulator: 2000000000000000000000000000,
            face_value: 50000000000000000000
        }
    );
}

#[test]
#[available_gas(30000000)]
fn test_transfer_all_should_emit_events() {
    let setup = setup();

    setup
        .alice
        .z_token_transfer_all(
            setup.z_token.contract_address, // contract_address
            setup.bob.contract_address // recipient
        );

    assert_event_emitted(
        setup.z_token.contract_address,
        event_keys::TRANSFER,
        @ZToken::Transfer {
            from: setup.alice.contract_address,
            to: setup.bob.contract_address,
            value: 200000000000000000000
        }
    );
    assert_event_emitted(
        setup.z_token.contract_address,
        event_keys::RAW_TRANSFER,
        @ZToken::RawTransfer {
            from: setup.alice.contract_address,
            to: setup.bob.contract_address,
            raw_value: 100000000000000000000,
            accumulator: 2000000000000000000000000000,
            face_value: 200000000000000000000
        }
    );
}

#[test]
#[available_gas(30000000)]
fn test_approve_should_change_allowance() {
    let setup = setup();

    assert_eq(
        @setup.z_token.allowance(setup.alice.contract_address, setup.bob.contract_address),
        @0,
        'FAILED'
    );

    setup
        .alice
        .erc20_approve(
            setup.z_token.contract_address, // contract_address
            setup.bob.contract_address, // spender
            50000000000000000000 // amount
        );
    setup
        .market
        .set_lending_accumulator(
            MOCK_TOKEN_ADDRESS.try_into().unwrap(), // token
             3000000000000000000000000000 // value
        );

    assert_eq(
        @setup.z_token.allowance(setup.alice.contract_address, setup.bob.contract_address),
        @50000000000000000000,
        'FAILED'
    );
}

#[test]
#[available_gas(30000000)]
fn test_transfer_from() {
    let setup = setup();

    // Alice allownace for Bob: 50
    // Alice balance: 400
    setup
        .alice
        .erc20_approve(
            setup.z_token.contract_address, // contract_address
            setup.bob.contract_address, // spender
            50000000000000000000 // amount
        );
    setup
        .market
        .set_lending_accumulator(
            MOCK_TOKEN_ADDRESS.try_into().unwrap(), // token
             4000000000000000000000000000 // value
        );

    // Bob transfers 40 from Alice
    // Balances double:
    //   Alice: (400 - 40) * 2 = 720
    //   Bob: 40 * 2 = 80
    //   Allowance: 50 - 40 = 10
    setup
        .bob
        .erc20_transfer_from(
            setup.z_token.contract_address, // contract_address
            setup.alice.contract_address, // sender
            setup.bob.contract_address, // recipient
            40000000000000000000 // amount
        );
    setup
        .market
        .set_lending_accumulator(
            MOCK_TOKEN_ADDRESS.try_into().unwrap(), // token
             8000000000000000000000000000 // value
        );

    assert_eq(
        @setup.z_token.allowance(setup.alice.contract_address, setup.bob.contract_address),
        @10000000000000000000,
        'FAILED'
    );
    assert_eq(
        @setup.z_token.balanceOf(setup.alice.contract_address), @720000000000000000000, 'FAILED'
    );
    assert_eq(
        @setup.z_token.balanceOf(setup.bob.contract_address), @80000000000000000000, 'FAILED'
    );
}

#[test]
#[available_gas(30000000)]
fn test_transfer_all() {
    let setup = setup();

    setup
        .alice
        .z_token_transfer_all(
            setup.z_token.contract_address, // contract_address
            setup.bob.contract_address // recipient
        );
    setup
        .market
        .set_lending_accumulator(
            MOCK_TOKEN_ADDRESS.try_into().unwrap(), // token
             4000000000000000000000000000 // value
        );

    assert_eq(@setup.z_token.balanceOf(setup.alice.contract_address), @0, 'FAILED');
    assert_eq(
        @setup.z_token.balanceOf(setup.bob.contract_address), @400000000000000000000, 'FAILED'
    );
}

#[test]
#[available_gas(30000000)]
fn test_burn_all() {
    let setup = setup();

    setup
        .market
        .mint_z_token(
            setup.z_token.contract_address, // z_token
            setup.bob.contract_address, // to
            100000000000000000000 // amount
        );
    setup
        .market
        .set_lending_accumulator(
            MOCK_TOKEN_ADDRESS.try_into().unwrap(), // token
             4000000000000000000000000000 // value
        );
    setup
        .market
        .burn_all_z_token(
            setup.z_token.contract_address, // z_token
             setup.alice.contract_address // user
        );

    assert_eq(@setup.market.get_last_call_result(), @400000000000000000000, 'FAILED');
    assert_eq(@setup.z_token.balanceOf(setup.alice.contract_address), @0, 'FAILED');
    assert_eq(
        @setup.z_token.balanceOf(setup.bob.contract_address), @200000000000000000000, 'FAILED'
    );
    assert_eq(@setup.z_token.totalSupply(), @200000000000000000000, 'FAILED');
}
