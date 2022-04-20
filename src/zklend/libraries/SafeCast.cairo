# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from starkware.cairo.common.math import split_felt
from starkware.cairo.common.uint256 import Uint256

func SafeCast_felt_to_uint256{range_check_ptr}(value : felt) -> (res : Uint256):
    # Nothing to check because `felt` can always be converted to `Uint256`
    let (high : felt, low : felt) = split_felt(value)
    return (res=Uint256(low=low, high=high))
end
