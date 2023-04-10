// SPDX-License-Identifier: MIT

%lang starknet

@contract_interface
namespace IZklendFlashCallback {
    func zklend_flash_callback(initiator: felt, calldata_len: felt, calldata: felt*) {
    }
}
