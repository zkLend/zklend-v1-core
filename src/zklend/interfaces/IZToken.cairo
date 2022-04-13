# SPDX-License-Identifier: BUSL-1.1

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IZToken:
    func mint(to : felt, amount : Uint256):
    end
end
