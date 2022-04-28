# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeDecimalMath import (
    SafeDecimalMath_div,
    SafeDecimalMath_mul,
    SafeDecimalMath_mul_decimals,
)

@view
func mul{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    with_attr error_message("mul failed"):
        return SafeDecimalMath_mul(a, b)
    end
end

@view
func div{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    with_attr error_message("div failed"):
        return SafeDecimalMath_div(a, b)
    end
end

@view
func mul_decimals{range_check_ptr}(a : felt, b : felt, b_decimals : felt) -> (res : felt):
    with_attr error_message("mul_decimals failed"):
        return SafeDecimalMath_mul_decimals(a, b, b_decimals)
    end
end
