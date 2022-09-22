// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from starkware.cairo.common.math import assert_le, split_felt
from starkware.cairo.common.uint256 import uint256_check, Uint256

namespace SafeCast {
    func felt_to_uint256{range_check_ptr}(value: felt) -> (res: Uint256) {
        // Nothing to check because `felt` can always be converted to `Uint256`
        let (high: felt, low: felt) = split_felt(value);
        return (res=Uint256(low=low, high=high));
    }

    func uint256_to_felt{range_check_ptr}(value: Uint256) -> (res: felt) {
        with_attr error_message("SafeCast: invalid uint256 value") {
            uint256_check(value);
        }
        return uint256_to_felt_unchecked(value);
    }

    // This method does NOT check if `value` is a valid `Uint256`. Callers MUST ensure it's valid.
    func uint256_to_felt_unchecked{range_check_ptr}(value: Uint256) -> (res: felt) {
        if (value.high == 0) {
            // Short circuit for small numbers
            // TODO: check if this branching makes sense
            return (res=value.low);
        } else {
            // PRIME - 1 is divisible by 2 ** 128
            const MAX_HIGH = (-1) / 2 ** 128;
            with_attr error_message("SafeCast: uint256 value out of range") {
                assert_le(value.high, MAX_HIGH);
                if (value.high == MAX_HIGH) {
                    assert value.low = 0;
                }
            }

            // No need to check `low` upper bound since it's already assumed to be valid
            return (res=value.high * 2 ** 128 + value.low);
        }
    }
}
