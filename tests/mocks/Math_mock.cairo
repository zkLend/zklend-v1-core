# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.Math import Math

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

@view
func shl{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(a : felt, b : felt) -> (res : felt):
    with_attr error_message("shl failed"):
        return Math.shl(a, b)
    end
end

@view
func shr{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    with_attr error_message("shr failed"):
        return Math.shr(a, b)
    end
end
