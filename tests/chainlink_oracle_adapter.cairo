use test::test_utils::assert_eq;

use zklend::interfaces::IPriceOracleSourceDispatcherTrait;

use tests::deploy;
use tests::mock::IMockChainlinkOracleDispatcherTrait;

#[test]
#[available_gas(30000000)]
fn test_not_staled_price() {
    let mock_chainlink_oracle = deploy::deploy_mock_chainlink_oracle();
    let chainlink_oracle_adpater = deploy::deploy_chainlink_oracle_adapter(
        mock_chainlink_oracle.contract_address, 500
    );

    // Set last update timestamp to 100
    mock_chainlink_oracle.set_price(5, 10000_00000000, 1, 0, 100);

    // Current block time is 0. It's okay for the updated time to be in the future.
    chainlink_oracle_adpater.get_price();

    // It's still acceptable when the time elasped equals timeout.
    starknet::testing::set_block_timestamp(600);
    chainlink_oracle_adpater.get_price();
}

#[test]
#[available_gas(30000000)]
#[should_panic(expected: ('CHAINLINK_STALED_PRICE', 'ENTRYPOINT_FAILED'))]
fn test_staled_price() {
    let mock_chainlink_oracle = deploy::deploy_mock_chainlink_oracle();
    let chainlink_oracle_adpater = deploy::deploy_chainlink_oracle_adapter(
        mock_chainlink_oracle.contract_address, 500
    );

    // Set last update timestamp to 100
    mock_chainlink_oracle.set_price(5, 10000_00000000, 1, 0, 100);

    // One second over timeout will be rejected.
    starknet::testing::set_block_timestamp(601);
    chainlink_oracle_adpater.get_price();
}
