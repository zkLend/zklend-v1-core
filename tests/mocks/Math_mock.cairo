# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.Math import Math_shr

@view
func shr{range_check_ptr}(a : felt, b : felt) -> (res : felt):
    with_attr error_message("shr failed"):
        return Math_shr(a, b)
    end
end
