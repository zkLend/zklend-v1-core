# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20

@external
func deposit{syscall_ptr : felt*, range_check_ptr}(token : felt, amount : Uint256):
    let (caller) = get_caller_address()
    let (this_address) = get_contract_address()

    let (transfer_success) = IERC20.transferFrom(
        contract_address=token, sender=caller, recipient=this_address, amount=amount
    )
    with_attr error_message("Market: transferFrom failed"):
        assert_not_zero(transfer_success)
    end

    return ()
end
