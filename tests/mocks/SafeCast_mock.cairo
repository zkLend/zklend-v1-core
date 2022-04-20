# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeCast import SafeCast_felt_to_uint256

from starkware.cairo.common.uint256 import Uint256

@view
func felt_to_uint256{range_check_ptr}(value : felt) -> (res : Uint256):
    with_attr error_message("felt_to_uint256 failed"):
        return SafeCast_felt_to_uint256(value)
    end
end
