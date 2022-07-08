# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeCast import SafeCast
from zklend.libraries.SafeMath import SafeMath

from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import uint256_mul, Uint256

namespace Math:
    # Computes the logical left shift of a field element, with result in the range of [0, 2 ** 251).
    # Note that this could be implemented with hints much more efficiently.
    # TODO: re-implement with hints and get hints whitelisted for StarkNet
    func shl{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(a : felt, b : felt) -> (res : felt):
        alloc_locals

        # For left shifting we pretend there're only 251 bits in `flt`.
        let (le_250) = is_le_felt(b, 250)
        if le_250 == 1:
            let (shift) = pow(2, b)
            let (shift_u256) = SafeCast.felt_to_uint256(shift)
            let (a_u256) = SafeCast.felt_to_uint256(a)

            let (product_low, _) = uint256_mul(a_u256, shift_u256)

            # Takes all 128 bits from low, and 123 bits from high
            let (trimmed_high) = bitwise_and(product_low.high, 2 ** 123 - 1)

            # This is definitely a valid `Uint256`
            let (res) = SafeCast.uint256_to_felt_unchecked(Uint256(product_low.low, trimmed_high))
            return (res=res)
        else:
            return (res=0)
        end
    end

    # Computes the logical right shift of a field element
    func shr{range_check_ptr}(a : felt, b : felt) -> (res : felt):
        let (le_251) = is_le_felt(b, 251)
        if le_251 == 1:
            let (denominator) = pow(2, b)
            let (res) = SafeMath.div(a, denominator)
            return (res=res)
        else:
            return (res=0)
        end
    end
end
