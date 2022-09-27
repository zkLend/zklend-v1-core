// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeCast import SafeCast

from starkware.cairo.common.math import assert_le_felt, assert_not_zero
from starkware.cairo.common.uint256 import uint256_mul, uint256_unsigned_div_rem

namespace SafeMath {
    func add{range_check_ptr}(a: felt, b: felt) -> felt {
        let sum = a + b;
        with_attr error_message("SafeMath: addition overflow") {
            assert_le_felt(a, sum);
        }
        return sum;
    }

    func sub{range_check_ptr}(a: felt, b: felt) -> felt {
        with_attr error_message("SafeMath: subtraction underflow") {
            assert_le_felt(b, a);
        }
        return a - b;
    }

    func mul{range_check_ptr}(a: felt, b: felt) -> felt {
        let a_uint256 = SafeCast.felt_to_uint256(a);
        let b_uint256 = SafeCast.felt_to_uint256(b);
        let (product_low, product_high) = uint256_mul(a_uint256, b_uint256);

        with_attr error_message("SafeMath: multiplication overflow") {
            assert product_high.low = 0;
            assert product_high.high = 0;
            return SafeCast.uint256_to_felt_unchecked(product_low);
        }
    }

    func div{range_check_ptr}(a: felt, b: felt) -> felt {
        with_attr error_message("SafeMath: division by zero") {
            assert_not_zero(b);
        }

        let a_uint256 = SafeCast.felt_to_uint256(a);
        let b_uint256 = SafeCast.felt_to_uint256(b);
        let (quotient, _) = uint256_unsigned_div_rem(a_uint256, b_uint256);

        return SafeCast.uint256_to_felt_unchecked(quotient);
    }
}
