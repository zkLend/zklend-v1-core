// SPDX-License-Identifier: BUSL-1.1

// DefaultInterestRateModel: IInterestRateModel

%lang starknet

from zklend.libraries.SafeDecimalMath import SafeDecimalMath, SCALE
from zklend.libraries.SafeMath import SafeMath

from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le_felt

//
// Structs
//

struct CurveParams {
    slope_0: felt,
    slope_1: felt,
    y_intercept: felt,
    optimal_rate: felt,
}

//
// Storage
//

// TODO: manually create copies of this contract with hard-coded values instead of using storage

@storage_var
func curve_params() -> (params: CurveParams) {
}

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    slope_0: felt, slope_1: felt, y_intercept: felt, optimal_rate: felt
) {
    // TODO: check `optimal_rate` range
    curve_params.write(
        CurveParams(
            slope_0=slope_0, slope_1=slope_1, y_intercept=y_intercept, optimal_rate=optimal_rate
        ),
    );
    return ();
}

//
// Getters
//

@view
func get_interest_rates{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    reserve_balance: felt, total_debt: felt
) -> (lending_rate: felt, borrowing_rate: felt) {
    alloc_locals;

    let (utilization_rate) = calculate_utilization_rate(reserve_balance, total_debt);
    if (utilization_rate == 0) {
        return (lending_rate=0, borrowing_rate=0);
    } else {
        let (borrowing_rate) = calculate_borrow_rate(utilization_rate);
        let lending_rate = SafeDecimalMath.mul(borrowing_rate, utilization_rate);
        return (lending_rate=lending_rate, borrowing_rate=borrowing_rate);
    }
}

func calculate_utilization_rate{range_check_ptr}(reserve_balance: felt, total_debt: felt) -> (
    utilization_rate: felt
) {
    if (total_debt == 0) {
        return (utilization_rate=0);
    } else {
        let total_liquidity = SafeMath.add(reserve_balance, total_debt);
        let utilization_rate = SafeDecimalMath.div(total_debt, total_liquidity);
        return (utilization_rate=utilization_rate);
    }
}

func calculate_borrow_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    utilization_rate: felt
) -> (borrow_rate: felt) {
    alloc_locals;

    let (params) = curve_params.read();

    let below_optimal_rate = is_le_felt(utilization_rate, params.optimal_rate);
    if (below_optimal_rate == TRUE) {
        let temp_1 = SafeDecimalMath.div(utilization_rate, params.optimal_rate);
        let temp_2 = SafeDecimalMath.mul(params.slope_0, temp_1);

        let borrow_rate = SafeMath.add(params.y_intercept, temp_2);

        return (borrow_rate=borrow_rate);
    } else {
        // No need to use safe math here
        let excess_utilization_rate = utilization_rate - params.optimal_rate;
        let optimal_to_one = SCALE - params.optimal_rate;

        let temp_1 = SafeDecimalMath.div(excess_utilization_rate, optimal_to_one);
        let temp_2 = SafeDecimalMath.mul(params.slope_1, temp_1);
        let temp_3 = SafeMath.add(params.y_intercept, params.slope_0);

        let borrow_rate = SafeMath.add(temp_2, temp_3);

        return (borrow_rate=borrow_rate);
    }
}
