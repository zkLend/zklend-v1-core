# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeCast import SafeCast_felt_to_uint256, SafeCast_uint256_to_felt

from starkware.cairo.common.math import assert_le_felt
from starkware.cairo.common.uint256 import uint256_mul, Uint256

func SafeMath_add{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    let sum = a + b
    with_attr error_message("SafeMath: addition overflow"):
        assert_le_felt(a, sum)
    end
    return (res=sum)
end

func SafeMath_sub{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    with_attr error_message("SafeMath: subtraction underflow"):
        assert_le_felt(b, a)
    end
    return (res=a - b)
end

func SafeMath_mul{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    let (a_uint256) = SafeCast_felt_to_uint256(a)
    let (b_uint256) = SafeCast_felt_to_uint256(b)
    let (product_low, product_high) = uint256_mul(a_uint256, b_uint256)

    with_attr error_message("SafeMath: multiplication overflow"):
        assert product_high.low = 0
        assert product_high.high = 0
        let (product) = SafeCast_uint256_to_felt(product_low)
        return (res=product)
    end
end
