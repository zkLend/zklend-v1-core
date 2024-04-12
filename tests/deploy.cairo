use array::ArrayTrait;
use option::OptionTrait;
use result::ResultTrait;
use traits::{Into, TryInto};

use starknet::ContractAddress;
use starknet::syscalls::deploy_syscall;

use zklend::interfaces::{
    IInterestRateModelDispatcher, IMarketDispatcher, IPriceOracleSourceDispatcher,
    ITestContractDispatcher, IZTokenDispatcher
};
use zklend::irms::default_interest_rate_model::DefaultInterestRateModel;
use zklend::market::Market;
use zklend::oracles::pragma_oracle_adapter::PragmaOracleAdapter;
use zklend::z_token::ZToken;

use tests::mock;
use tests::mock::{
    IAccountDispatcher, IERC20Dispatcher, IFlashLoanHandlerDispatcher, IMockMarketDispatcher,
    IMockPragmaOracleDispatcher, IMockPriceOracleDispatcher
};

fn deploy_account(salt: felt252) -> IAccountDispatcher {
    let (contract_address, _) = deploy_syscall(
        mock::account::Account::TEST_CLASS_HASH.try_into().unwrap(),
        salt,
        Default::default().span(),
        false
    )
        .unwrap();

    IAccountDispatcher { contract_address }
}

fn deploy_erc20(
    name: felt252, symbol: felt252, decimals: u8, initial_supply: u256, recipient: ContractAddress
) -> IERC20Dispatcher {
    let (contract_address, _) = deploy_syscall(
        mock::erc20::ERC20::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        array![
            name,
            symbol,
            decimals.into(),
            initial_supply.low.into(),
            initial_supply.high.into(),
            recipient.into()
        ]
            .span(),
        false
    )
        .unwrap();

    IERC20Dispatcher { contract_address }
}

fn deploy_mock_price_oracle() -> IMockPriceOracleDispatcher {
    let (contract_address, _) = deploy_syscall(
        mock::mock_price_oracle::MockPriceOracle::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        Default::default().span(),
        false
    )
        .unwrap();

    IMockPriceOracleDispatcher { contract_address }
}

fn deploy_mock_pragma_oracle() -> IMockPragmaOracleDispatcher {
    let (contract_address, _) = deploy_syscall(
        mock::mock_pragma_oracle::MockPragmaOracle::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        Default::default().span(),
        false
    )
        .unwrap();

    IMockPragmaOracleDispatcher { contract_address }
}

fn deploy_mock_market() -> IMockMarketDispatcher {
    let (contract_address, _) = deploy_syscall(
        mock::mock_market::MockMarket::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        Default::default().span(),
        false
    )
        .unwrap();

    IMockMarketDispatcher { contract_address }
}

fn deploy_flash_loan_handler() -> IFlashLoanHandlerDispatcher {
    let (contract_address, _) = deploy_syscall(
        mock::flash_loan_handler::FlashLoanHandler::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        Default::default().span(),
        false
    )
        .unwrap();

    IFlashLoanHandlerDispatcher { contract_address }
}

fn deploy_pragma_oracle_adapter(
    oracle: ContractAddress, pair: felt252, timeout: felt252
) -> IPriceOracleSourceDispatcher {
    let (contract_address, _) = deploy_syscall(
        PragmaOracleAdapter::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        array![oracle.into(), pair, timeout].span(),
        false
    )
        .unwrap();

    IPriceOracleSourceDispatcher { contract_address }
}

fn deploy_default_interest_rate_model(
    slope_0: felt252, slope_1: felt252, y_intercept: felt252, optimal_rate: felt252
) -> IInterestRateModelDispatcher {
    let (contract_address, _) = deploy_syscall(
        DefaultInterestRateModel::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        array![slope_0, slope_1, y_intercept, optimal_rate].span(),
        false
    )
        .unwrap();

    IInterestRateModelDispatcher { contract_address }
}

fn deploy_z_token(
    owner: ContractAddress,
    market: ContractAddress,
    underlying: ContractAddress,
    name: felt252,
    symbol: felt252,
    decimals: felt252
) -> IZTokenDispatcher {
    let (contract_address, _) = deploy_syscall(
        ZToken::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        array![owner.into(), market.into(), underlying.into(), name, symbol, decimals].span(),
        false
    )
        .unwrap();

    IZTokenDispatcher { contract_address }
}

fn deploy_market(owner: ContractAddress, oracle: ContractAddress) -> IMarketDispatcher {
    let (contract_address, _) = deploy_syscall(
        Market::TEST_CLASS_HASH.try_into().unwrap(),
        0,
        array![owner.into(), oracle.into()].span(),
        false
    )
        .unwrap();

    IMarketDispatcher { contract_address }
}
