# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeMath import SafeMath_div, SafeMath_mul

from starkware.cairo.common.pow import pow

const SCALE = 10 ** 27

# This function assumes `b` is scaled by `SCALE`
func SafeDecimalMath_mul{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    let (scaled_product) = SafeMath_mul(a, b)
    let (result) = SafeMath_div(scaled_product, SCALE)
    return (res=result)
end

# This function assumes `b` is scaled by `SCALE`
func SafeDecimalMath_div{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    let (scaled_a) = SafeMath_mul(a, SCALE)
    let (result) = SafeMath_div(scaled_a, b)
    return (res=result)
end

# This function assumes `b` is scaled by `10 ** b_decimals`
func SafeDecimalMath_mul_decimals{range_check_ptr}(a : felt, b : felt, b_decimals : felt) -> (
    res : felt
):
    alloc_locals

    # TODO: check `b_decimals` range

    let (scaled_product) = SafeMath_mul(a, b)
    let (scale) = pow(10, b_decimals)
    let (result) = SafeMath_div(scaled_product, scale)
    return (res=result)
end

func SafeDecimalMath_div_decimals{range_check_ptr}(a : felt, b : felt, b_decimals : felt) -> (
    res : felt
):
    # TODO: check `b_decimals` range

    let (scale) = pow(10, b_decimals)
    let (scaled_a) = SafeMath_mul(a, scale)
    let (result) = SafeMath_div(scaled_a, b)
    return (res=result)
end
