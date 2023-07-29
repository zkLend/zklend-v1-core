use test::test_utils::assert_eq;

use zklend::interfaces::IInterestRateModelDispatcherTrait;

use tests::deploy;

#[test]
#[available_gas(30000000)]
fn test_borrow_rates() {
    // slope_0: 0.1
    // slope_1: 0.5
    // y_intercept: 1%
    // optimal_rate: 80%
    let default_interest_rate_model = deploy::deploy_default_interest_rate_model(
        100000000000000000000000000, // slope_0
        500000000000000000000000000, // slope_1
        10000000000000000000000000, // y_intercept
        800000000000000000000000000, // optimal_rate
    );

    // 0% utilized: 0%
    assert_eq(@default_interest_rate_model.get_interest_rates(100, 0).borrowing_rate, @0, 'FAILED');

    // 10% utilized:
    //   1% + 0.1 * (10% / 80%) = 2.25%
    assert_eq(
        @default_interest_rate_model.get_interest_rates(90, 10).borrowing_rate,
        @22500000000000000000000000,
        'FAILED'
    );

    // 50% utilized:
    //   1% + 0.1 * (50% / 80%) = 7.25%
    assert_eq(
        @default_interest_rate_model.get_interest_rates(50, 50).borrowing_rate,
        @72500000000000000000000000,
        'FAILED'
    );

    // 60% utilized:
    //   1% + 0.1 * (60% / 80%) = 8.5%
    assert_eq(
        @default_interest_rate_model.get_interest_rates(40, 60).borrowing_rate,
        @85000000000000000000000000,
        'FAILED'
    );

    // 70% utilized:
    //   1% + 0.1 * (70% / 80%) = 9.75%
    assert_eq(
        @default_interest_rate_model.get_interest_rates(30, 70).borrowing_rate,
        @97500000000000000000000000,
        'FAILED'
    );

    // 90% utilized:
    //   1% + 0.1 + 0.5 * (90% - 80%) / (100% - 80%) = 36%
    assert_eq(
        @default_interest_rate_model.get_interest_rates(10, 90).borrowing_rate,
        @360000000000000000000000000,
        'FAILED'
    );

    // 100% utilized:
    //   1% + 0.1 + 0.5 * (100% - 80%) / (100% - 80%) = 61%
    assert_eq(
        @default_interest_rate_model.get_interest_rates(0, 100).borrowing_rate,
        @610000000000000000000000000,
        'FAILED'
    );
}

