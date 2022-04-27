# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.Math import Math_shl, Math_shr

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

@view
func shl{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(a : felt, b : felt) -> (res : felt):
    with_attr error_message("shl failed"):
        return Math_shl(a, b)
    end
end

@view
func shr{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    with_attr error_message("shr failed"):
        return Math_shr(a, b)
    end
end
