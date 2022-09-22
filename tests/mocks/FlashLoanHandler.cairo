// SPDX-License-Identifier: BUSL-1.1

%lang starknet

from zklend.interfaces.IMarket import IMarket
from zklend.libraries.SafeCast import SafeCast

from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_contract_address

from openzeppelin.token.erc20.IERC20 import IERC20

@external
func take_flash_loan{syscall_ptr: felt*, range_check_ptr}(
    market_addr: felt, token: felt, amount: felt, return_amount: felt
) {
    alloc_locals;

    let (this_address) = get_contract_address();

    // Encodes return token, recipient, and amount into callback calldata
    let (local calldata: felt*) = alloc();
    assert calldata[0] = token;
    assert calldata[1] = market_addr;
    assert calldata[2] = return_amount;

    IMarket.flash_loan(
        contract_address=market_addr,
        receiver=this_address,
        token=token,
        amount=amount,
        calldata_len=3,
        calldata=calldata,
    );

    return ();
}

// **IMPORANT**: in a real contract, ALWAYS check the callback is being called from the real market
// contract! We're encoding the market address into callback data for simplicity only (avoid having
// to handle storage in a mock contract).
@external
func zklend_flash_callback{syscall_ptr: felt*, range_check_ptr}(
    calldata_len: felt, calldata: felt*
) {
    let token = calldata[0];
    let market_addr = calldata[1];
    let return_amount = calldata[2];

    let (return_amount_u256) = SafeCast.felt_to_uint256(return_amount);

    IERC20.transfer(contract_address=token, recipient=market_addr, amount=return_amount_u256);

    return ();
}
