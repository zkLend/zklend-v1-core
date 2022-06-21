# SPDX-License-Identifier: BUSL-1.1

# DefaultInterestRateModel: IInterestRateModel

%lang starknet

from zklend.libraries.SafeDecimalMath import SafeDecimalMath_div, SafeDecimalMath_mul, SCALE
from zklend.libraries.SafeMath import SafeMath_add

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le_felt

from openzeppelin.utils.constants import TRUE

#
# Structs
#

struct CurveParams:
    member slope_0 : felt
    member slope_1 : felt
    member y_intercept : felt
    member optimal_rate : felt
end

#
# Storage
#

# TODO: manually create copies of this contract with hard-coded values instead of using storage

@storage_var
func curve_params() -> (params : CurveParams):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    slope_0 : felt, slope_1 : felt, y_intercept : felt, optimal_rate : felt
):
    curve_params.write(
        CurveParams(
        slope_0=slope_0,
        slope_1=slope_1,
        y_intercept=y_intercept, optimal_rate=optimal_rate
        ),
    )
    return ()
end

#
# Getters
#

@view
func get_interest_rates{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reserve_balance : felt, total_debt : felt
) -> (lending_rate : felt, borrowing_rate : felt):
    alloc_locals

    let (utilization_rate) = calculate_utilization_rate(reserve_balance, total_debt)
    if utilization_rate == 0:
        return (lending_rate=0, borrowing_rate=0)
    else:
        let (borrowing_rate) = calculate_borrow_rate(utilization_rate)
        let (lending_rate) = SafeDecimalMath_mul(borrowing_rate, utilization_rate)
        return (lending_rate=lending_rate, borrowing_rate=borrowing_rate)
    end
end

func calculate_utilization_rate{range_check_ptr}(reserve_balance : felt, total_debt : felt) -> (
    utilization_rate : felt
):
    if total_debt == 0:
        return (utilization_rate=0)
    else:
        let (total_liquidity) = SafeMath_add(reserve_balance, total_debt)
        let (utilization_rate) = SafeDecimalMath_div(total_debt, total_liquidity)
        return (utilization_rate=utilization_rate)
    end
end

func calculate_borrow_rate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    utilization_rate : felt
) -> (borrow_rate : felt):
    alloc_locals

    let (params) = curve_params.read()

    let (below_optimal_rate) = is_le_felt(utilization_rate, params.optimal_rate)
    if below_optimal_rate == TRUE:
        let (temp_1) = SafeDecimalMath_mul(utilization_rate, params.slope_0)
        let (borrow_rate) = SafeMath_add(temp_1, params.y_intercept)

        return (borrow_rate=borrow_rate)
    else:
        # TODO: calculate `temp_2` in constructor directly
        let (temp_1) = SafeDecimalMath_mul(params.optimal_rate, params.slope_0)
        let (temp_2) = SafeMath_add(temp_1, params.y_intercept)

        # No need to use safe math here
        let excess_utilization_rate = utilization_rate - params.optimal_rate
        let (temp_3) = SafeDecimalMath_mul(excess_utilization_rate, params.slope_1)
        let (borrow_rate) = SafeMath_add(temp_2, temp_3)

        return (borrow_rate=borrow_rate)
    end
end
