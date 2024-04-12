mod errors {
    const INVALID_OPTIMAL_RATE: felt252 = 'DIRM_INVALID_OPTIMAL_RATE';
}

// TODO: manually create copies of this contract with hard-coded values instead of using storage
#[starknet::contract]
mod DefaultInterestRateModel {
    use traits::Into;

    // Hack to simulate the `crate` keyword
    use super::super::super as crate;

    use crate::interfaces::{IInterestRateModel, ModelRates};
    use crate::libraries::{safe_decimal_math, safe_math};

    use super::errors;

    #[storage]
    struct Storage {
        curve_params: CurveParams
    }

    #[derive(Drop, starknet::Store)]
    struct CurveParams {
        slope_0: felt252,
        slope_1: felt252,
        y_intercept: felt252,
        optimal_rate: felt252
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        slope_0: felt252,
        slope_1: felt252,
        y_intercept: felt252,
        optimal_rate: felt252
    ) {
        assert(
            Into::<_, u256>::into(optimal_rate) <= Into::<_, u256>::into(safe_decimal_math::SCALE),
            errors::INVALID_OPTIMAL_RATE
        );

        self.curve_params.write(CurveParams { slope_0, slope_1, y_intercept, optimal_rate });
    }

    #[abi(embed_v0)]
    impl IInterestRateModelImpl of IInterestRateModel<ContractState> {
        fn get_interest_rates(
            self: @ContractState, reserve_balance: felt252, total_debt: felt252
        ) -> ModelRates {
            let utilization_rate = calculate_utilization_rate(reserve_balance, total_debt);
            if utilization_rate == 0 {
                ModelRates { lending_rate: 0, borrowing_rate: 0 }
            } else {
                let borrowing_rate = calculate_borrow_rate(self, utilization_rate);
                let lending_rate = safe_decimal_math::mul(borrowing_rate, utilization_rate);
                ModelRates { lending_rate, borrowing_rate }
            }
        }
    }

    fn calculate_utilization_rate(reserve_balance: felt252, total_debt: felt252) -> felt252 {
        if total_debt == 0 {
            0
        } else {
            let total_liquidity = safe_math::add(reserve_balance, total_debt);
            let utilization_rate = safe_decimal_math::div(total_debt, total_liquidity);
            utilization_rate
        }
    }

    fn calculate_borrow_rate(self: @ContractState, utilization_rate: felt252) -> felt252 {
        let params = self.curve_params.read();

        let below_optimal_rate = Into::<
            _, u256
            >::into(utilization_rate) <= Into::<
            _, u256
        >::into(params.optimal_rate);

        if below_optimal_rate {
            let temp_1 = safe_decimal_math::div(utilization_rate, params.optimal_rate);
            let temp_2 = safe_decimal_math::mul(params.slope_0, temp_1);

            let borrow_rate = safe_math::add(params.y_intercept, temp_2);

            borrow_rate
        } else {
            // No need to use safe math here
            let excess_utilization_rate = utilization_rate - params.optimal_rate;
            let optimal_to_one = safe_decimal_math::SCALE - params.optimal_rate;

            let temp_1 = safe_decimal_math::div(excess_utilization_rate, optimal_to_one);
            let temp_2 = safe_decimal_math::mul(params.slope_1, temp_1);
            let temp_3 = safe_math::add(params.y_intercept, params.slope_0);

            let borrow_rate = safe_math::add(temp_2, temp_3);

            borrow_rate
        }
    }
}
