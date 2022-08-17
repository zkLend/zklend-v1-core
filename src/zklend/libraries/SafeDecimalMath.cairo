# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeMath import SafeMath

from starkware.cairo.common.math import assert_le_felt
from starkware.cairo.common.pow import pow

const SCALE = 10 ** 27

namespace SafeDecimalMath:
    # This function assumes `b` is scaled by `SCALE`
    func mul{range_check_ptr}(a : felt, b : felt) -> (res : felt):
        let (scaled_product) = SafeMath.mul(a, b)
        let (result) = SafeMath.div(scaled_product, SCALE)
        return (res=result)
    end

    # This function assumes `b` is scaled by `SCALE`
    func div{range_check_ptr}(a : felt, b : felt) -> (res : felt):
        let (scaled_a) = SafeMath.mul(a, SCALE)
        let (result) = SafeMath.div(scaled_a, b)
        return (res=result)
    end

    # This function assumes `b` is scaled by `10 ** b_decimals`
    func mul_decimals{range_check_ptr}(a : felt, b : felt, b_decimals : felt) -> (res : felt):
        alloc_locals

        # `pow` overflows if `b_decimals` > 75,
        with_attr error_message("Market: decimlas out of range"):
            assert_le_felt(b_decimals, 75)
        end

        let (scaled_product) = SafeMath.mul(a, b)
        let (scale) = pow(10, b_decimals)
        let (result) = SafeMath.div(scaled_product, scale)
        return (res=result)
    end

    func div_decimals{range_check_ptr}(a : felt, b : felt, b_decimals : felt) -> (res : felt):
        # `pow` overflows if `b_decimals` > 75,
        with_attr error_message("Market: decimlas out of range"):
            assert_le_felt(b_decimals, 75)
        end

        let (scale) = pow(10, b_decimals)
        let (scaled_a) = SafeMath.mul(a, scale)
        let (result) = SafeMath.div(scaled_a, b)
        return (res=result)
    end
end
