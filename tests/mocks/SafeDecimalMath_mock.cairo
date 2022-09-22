// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeDecimalMath import SafeDecimalMath

@view
func mul{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("mul failed") {
        let res = SafeDecimalMath.mul(a, b);
        return (res=res);
    }
}

@view
func div{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("div failed") {
        let res = SafeDecimalMath.div(a, b);
        return (res=res);
    }
}

@view
func mul_decimals{range_check_ptr}(a: felt, b: felt, b_decimals: felt) -> (res: felt) {
    with_attr error_message("mul_decimals failed") {
        let res = SafeDecimalMath.mul_decimals(a, b, b_decimals);
        return (res=res);
    }
}
