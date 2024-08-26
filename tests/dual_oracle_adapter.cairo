use test::test_utils::assert_eq;

use zklend::interfaces::IPriceOracleSourceDispatcherTrait;

use tests::deploy;
use tests::mock::{IMockChainlinkOracleDispatcherTrait, IMockPragmaOracleDispatcherTrait};

#[test]
#[available_gas(30000000)]
fn test_average_price() {
    let mock_chainlink_oracle = deploy::deploy_mock_chainlink_oracle();
    let mock_pragma_oracle = deploy::deploy_mock_pragma_oracle();

    let chainlink_oracle_adpater = deploy::deploy_chainlink_oracle_adapter(
        mock_chainlink_oracle.contract_address, 500
    );
    let pragma_oracle_adpater = deploy::deploy_pragma_oracle_adapter(
        mock_pragma_oracle.contract_address, 'BTC/USD', 500
    );

    // 10% threshold
    let dual_oracle_adapter = deploy::deploy_dual_oracle_adapter(
        chainlink_oracle_adpater.contract_address,
        pragma_oracle_adpater.contract_address,
        0_100000000000000000000000000
    );

    // Chainlink: 10000; Pragma: 10100
    mock_chainlink_oracle.set_price(5, 10000_00000000, 1, 0, 100);
    mock_pragma_oracle.set_price('BTC/USD', 10100_00000000, 8, 100, 5);
    assert(dual_oracle_adapter.get_price() == 10050_00000000, 'FAILED');

    // Chainlink: 10100; Pragma: 10000
    mock_chainlink_oracle.set_price(5, 10100_00000000, 1, 0, 100);
    mock_pragma_oracle.set_price('BTC/USD', 10000_00000000, 8, 100, 5);
    assert(dual_oracle_adapter.get_price() == 10050_00000000, 'FAILED');

    // Same price
    mock_chainlink_oracle.set_price(5, 10400_00000000, 1, 0, 100);
    mock_pragma_oracle.set_price('BTC/USD', 10400_00000000, 8, 100, 5);
    assert(dual_oracle_adapter.get_price() == 10400_00000000, 'FAILED');

    // Exactly on threshold
    mock_chainlink_oracle.set_price(5, 10000_00000000, 1, 0, 100);
    mock_pragma_oracle.set_price('BTC/USD', 11000_00000000, 8, 100, 5);
    assert(dual_oracle_adapter.get_price() == 10500_00000000, 'FAILED');

    // The other way around
    mock_chainlink_oracle.set_price(5, 11000_00000000, 1, 0, 100);
    mock_pragma_oracle.set_price('BTC/USD', 10000_00000000, 8, 100, 5);
    assert(dual_oracle_adapter.get_price() == 10500_00000000, 'FAILED');
}

#[test]
#[available_gas(30000000)]
#[should_panic(expected: ('DUAL_DIVERGING_UPSTREAMS', 'ENTRYPOINT_FAILED'))]
fn test_diverged_upstreams_with_0_lower() {
    let mock_chainlink_oracle = deploy::deploy_mock_chainlink_oracle();
    let mock_pragma_oracle = deploy::deploy_mock_pragma_oracle();

    let chainlink_oracle_adpater = deploy::deploy_chainlink_oracle_adapter(
        mock_chainlink_oracle.contract_address, 500
    );
    let pragma_oracle_adpater = deploy::deploy_pragma_oracle_adapter(
        mock_pragma_oracle.contract_address, 'BTC/USD', 500
    );

    // 10% threshold
    let dual_oracle_adapter = deploy::deploy_dual_oracle_adapter(
        chainlink_oracle_adpater.contract_address,
        pragma_oracle_adpater.contract_address,
        0_100000000000000000000000000
    );

    // Chainlink: 10000; Pragma: 11000.00000001
    mock_chainlink_oracle.set_price(5, 10000_00000000, 1, 0, 100);
    mock_pragma_oracle.set_price('BTC/USD', 11000_00000001, 8, 100, 5);
    dual_oracle_adapter.get_price();
}

#[test]
#[available_gas(30000000)]
#[should_panic(expected: ('DUAL_DIVERGING_UPSTREAMS', 'ENTRYPOINT_FAILED'))]
fn test_diverged_upstreams_with_1_lower() {
    let mock_chainlink_oracle = deploy::deploy_mock_chainlink_oracle();
    let mock_pragma_oracle = deploy::deploy_mock_pragma_oracle();

    let chainlink_oracle_adpater = deploy::deploy_chainlink_oracle_adapter(
        mock_chainlink_oracle.contract_address, 500
    );
    let pragma_oracle_adpater = deploy::deploy_pragma_oracle_adapter(
        mock_pragma_oracle.contract_address, 'BTC/USD', 500
    );

    // 10% threshold
    let dual_oracle_adapter = deploy::deploy_dual_oracle_adapter(
        chainlink_oracle_adpater.contract_address,
        pragma_oracle_adpater.contract_address,
        0_100000000000000000000000000
    );

    // Chainlink: 11000.00000001; Pragma: 10000
    mock_chainlink_oracle.set_price(5, 11000_00000001, 1, 0, 100);
    mock_pragma_oracle.set_price('BTC/USD', 10000_00000000, 8, 100, 5);
    dual_oracle_adapter.get_price();
}
