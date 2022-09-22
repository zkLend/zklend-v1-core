// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeDecimalMath import SafeDecimalMath

@view
func mul{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("mul failed") {
        return SafeDecimalMath.mul(a, b);
    }
}

@view
func div{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("div failed") {
        return SafeDecimalMath.div(a, b);
    }
}

@view
func mul_decimals{range_check_ptr}(a: felt, b: felt, b_decimals: felt) -> (res: felt) {
    with_attr error_message("mul_decimals failed") {
        return SafeDecimalMath.mul_decimals(a, b, b_decimals);
    }
}
