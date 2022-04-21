# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from starkware.cairo.common.math import assert_le_felt

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
