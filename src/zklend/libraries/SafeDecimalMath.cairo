// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeMath import SafeMath

from starkware.cairo.common.math import assert_le_felt
from starkware.cairo.common.pow import pow

const SCALE = 10 ** 27;

namespace SafeDecimalMath {
    func mul{range_check_ptr}(a: felt, b: felt) -> felt {
        let scaled_product = SafeMath.mul(a, b);
        return SafeMath.div(scaled_product, SCALE);
    }

    func div{range_check_ptr}(a: felt, b: felt) -> felt {
        let scaled_a = SafeMath.mul(a, SCALE);
        return SafeMath.div(scaled_a, b);
    }

    func mul_decimals{range_check_ptr}(a: felt, b: felt, b_decimals: felt) -> felt {
        alloc_locals;

        with_attr error_message("Market: decimals out of range") {
            assert_le_felt(b_decimals, 75);
        }

        let scaled_product = SafeMath.mul(a, b);
        let (scale) = pow(10, b_decimals);
        return SafeMath.div(scaled_product, scale);
    }

    func div_decimals{range_check_ptr}(a: felt, b: felt, b_decimals: felt) -> felt {
        with_attr error_message("Market: decimals out of range") {
            assert_le_felt(b_decimals, 75);
        }

        let (scale) = pow(10, b_decimals);
        let scaled_a = SafeMath.mul(a, scale);
        return SafeMath.div(scaled_a, b);
    }
}
