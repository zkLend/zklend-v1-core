# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeMath import SafeMath_div

from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.pow import pow

# Computes the logical right shift of a field element
func Math_shr{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    let (le_251) = is_le_felt(b, 251)
    if le_251 == 1:
        let (denominator) = pow(2, b)
        let (res) = SafeMath_div(a, denominator)
        return (res=res)
    else:
        return (res=0)
    end
end
