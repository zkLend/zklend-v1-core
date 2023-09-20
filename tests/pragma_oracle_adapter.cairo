use test::test_utils::assert_eq;

use zklend::interfaces::IPriceOracleSourceDispatcherTrait;

use tests::deploy;
use tests::mock::IMockPragmaOracleDispatcherTrait;

#[test]
#[available_gas(30000000)]
fn test_not_staled_price() {
    let mock_pragma_oracle = deploy::deploy_mock_pragma_oracle();
    let pragma_oracle_adpater = deploy::deploy_pragma_oracle_adapter(
        mock_pragma_oracle.contract_address, 'BTC/USD', 500
    );

    // Set last update timestamp to 100
    mock_pragma_oracle.set_price('BTC/USD', 10000_00000000, 8, 100, 5);

    // Current block time is 0. It's okay for the updated time to be in the future.
    pragma_oracle_adpater.get_price();

    // It's still acceptable when the time elasped equals timeout.
    starknet::testing::set_block_timestamp(600);
    pragma_oracle_adpater.get_price();
}

#[test]
#[available_gas(30000000)]
#[should_panic(expected: ('PRAGMA_STALED_PRICE', 'ENTRYPOINT_FAILED'))]
fn test_staled_price() {
    let mock_pragma_oracle = deploy::deploy_mock_pragma_oracle();
    let pragma_oracle_adpater = deploy::deploy_pragma_oracle_adapter(
        mock_pragma_oracle.contract_address, 'BTC/USD', 500
    );

    // Set last update timestamp to 100
    mock_pragma_oracle.set_price('BTC/USD', 10000_00000000, 8, 100, 5);

    // One second over timeout will be rejected.
    starknet::testing::set_block_timestamp(601);
    pragma_oracle_adpater.get_price();
}
