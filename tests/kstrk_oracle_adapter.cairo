use starknet::contract_address_const;

use test::test_utils::assert_eq;

use zklend::interfaces::IPriceOracleSourceDispatcherTrait;

use tests::deploy;
use tests::mock::{IMockKstrkPoolDispatcherTrait, IMockPragmaOracleDispatcherTrait};

#[test]
#[available_gas(30000000)]
fn test_price() {
    let mock_pragma_oracle = deploy::deploy_mock_pragma_oracle();

    // STRK price: 0.5
    mock_pragma_oracle.set_price('STRK/USD', 0_50000000, 8, 100, 5);

    // kSTRK total supply: 100
    let mock_kstrk_token = deploy::deploy_erc20(
        'kSTRK', 'kSTRK', 18, 100_000000000000000000, contract_address_const::<1>()
    );

    let mock_kstrk_pool = deploy::deploy_mock_kstrk_pool();
    mock_kstrk_pool.set_staked_token(mock_kstrk_token.contract_address);

    let pragma_oracle_adpater = deploy::deploy_pragma_oracle_adapter(
        mock_pragma_oracle.contract_address, 'STRK/USD', 500
    );
    let kstrk_oracle_adapter = deploy::deploy_kstrk_oracle_adapter(
        pragma_oracle_adpater.contract_address, mock_kstrk_pool.contract_address
    );

    // Pool size: 100 STRK
    // Exchange rate: 1 kSTRK = 1 STRK
    // Price: 0.5
    mock_kstrk_pool.set_total_stake(100_000000000000000000);
    assert(kstrk_oracle_adapter.get_price() == 0_50000000, 'FAILED');

    // Pool size: 120 STRK
    // Exchange rate: 1 kSTRK = 1.2 STRK
    // Price: 0.6
    mock_kstrk_pool.set_total_stake(120_000000000000000000);
    assert(kstrk_oracle_adapter.get_price() == 0_60000000, 'FAILED');

    // NOTE: this scenario should be impossible but is tested anyway
    //
    // Pool size: 80 STRK
    // Exchange rate: 1 kSTRK = 0.8 STRK
    // Price: 0.4
    mock_kstrk_pool.set_total_stake(80_000000000000000000);
    assert(kstrk_oracle_adapter.get_price() == 0_40000000, 'FAILED');
}
