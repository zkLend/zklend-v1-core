// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeCast import SafeCast

from starkware.cairo.common.uint256 import Uint256

@view
func felt_to_uint256{range_check_ptr}(value: felt) -> (res: Uint256) {
    with_attr error_message("felt_to_uint256 failed") {
        let res = SafeCast.felt_to_uint256(value);
        return (res=res);
    }
}

@view
func uint256_to_felt{range_check_ptr}(value: Uint256) -> (res: felt) {
    with_attr error_message("uint256_to_felt failed") {
        let res = SafeCast.uint256_to_felt(value);
        return (res=res);
    }
}

@view
func uint256_to_felt_unchecked{range_check_ptr}(value: Uint256) -> (res: felt) {
    with_attr error_message("uint256_to_felt_unchecked failed") {
        let res = SafeCast.uint256_to_felt_unchecked(value);
        return (res=res);
    }
}
