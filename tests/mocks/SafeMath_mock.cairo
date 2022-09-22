// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.libraries.SafeMath import SafeMath

@view
func add{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("add failed") {
        let res = SafeMath.add(a, b);
        return (res=res);
    }
}

@view
func sub{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("sub failed") {
        let res = SafeMath.sub(a, b);
        return (res=res);
    }
}

@view
func mul{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("mul failed") {
        let res = SafeMath.mul(a, b);
        return (res=res);
    }
}

@view
func div{range_check_ptr}(a: felt, b: felt) -> (res: felt) {
    with_attr error_message("div failed") {
        let res = SafeMath.div(a, b);
        return (res=res);
    }
}
