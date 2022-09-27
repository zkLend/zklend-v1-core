// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeMath import SafeMath

from starkware.cairo.common.math import assert_le_felt
from starkware.cairo.common.pow import pow

const SCALE = 10 ** 27;

namespace SafeDecimalMath {
    // This function assumes `b` is scaled by `SCALE`
    func mul{range_check_ptr}(a: felt, b: felt) -> felt {
        let scaled_product = SafeMath.mul(a, b);
        return SafeMath.div(scaled_product, SCALE);
    }

    // This function assumes `b` is scaled by `SCALE`
    func div{range_check_ptr}(a: felt, b: felt) -> felt {
        let scaled_a = SafeMath.mul(a, SCALE);
        return SafeMath.div(scaled_a, b);
    }

    // This function assumes `b` is scaled by `10 ** b_decimals`
    func mul_decimals{range_check_ptr}(a: felt, b: felt, b_decimals: felt) -> felt {
        alloc_locals;

        // `pow` overflows if `b_decimals` > 75,
        with_attr error_message("Market: decimals out of range") {
            assert_le_felt(b_decimals, 75);
        }

        let scaled_product = SafeMath.mul(a, b);
        let (scale) = pow(10, b_decimals);
        return SafeMath.div(scaled_product, scale);
    }

    func div_decimals{range_check_ptr}(a: felt, b: felt, b_decimals: felt) -> felt {
        // `pow` overflows if `b_decimals` > 75,
        with_attr error_message("Market: decimals out of range") {
            assert_le_felt(b_decimals, 75);
        }

        let (scale) = pow(10, b_decimals);
        let scaled_a = SafeMath.mul(a, scale);
        return SafeMath.div(scaled_a, b);
    }
}
