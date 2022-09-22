// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeMath import SafeMath

@view
func add{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("add failed") {
        return SafeMath.add(a, b);
    }
}

@view
func sub{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("sub failed") {
        return SafeMath.sub(a, b);
    }
}

@view
func mul{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("mul failed") {
        return SafeMath.mul(a, b);
    }
}

@view
func div{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("div failed") {
        return SafeMath.div(a, b);
    }
}
