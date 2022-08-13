# SPDX-License-Identifier: MIT

%lang starknet

@contract_interface
namespace IZklendFlashCallback:
    func zklend_flash_callback(calldata_len : felt, calldata : felt*):
    end
end
