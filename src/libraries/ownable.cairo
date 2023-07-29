// This is a re-implementation of OpenZeppelin's Cairo 0 `Ownable` library (v0.6.1):
//
// https://github.com/OpenZeppelin/cairo-contracts/blob/4dd04250c55ae8a5bbcb72663c989bb204e8d998/src/openzeppelin/access/ownable/library.cairo
//
// Not using their own Cairo 1 version because, as of this writing:
//
// 1. It's not officially released yet (v0.6.1 is still the latest release);
// 2. It's implemented as a contract instead of a library, so there seems to be no way to integrate
//    into our contract;
// 3. It changed from using the `Ownable_owner` storage slot to `_owner`, which is a breaking
//    change. We need to maintain storage backward compatibility;
// 4. Our re-implementation here is more flexible by abstracting away storage and events.

use zeroable::Zeroable;

use starknet::{ContractAddress, contract_address_const, get_caller_address};

mod errors {
    const NOT_OWNER: felt252 = 'OWN_NOT_OWNER';
    const ZERO_ADDRESS: felt252 = 'OWN_ZERO_ADDRESS';
}

/// This trait abstracts away the `ownable` library's interaction with the parent contract.
trait Ownable<T> {
    // Storage proxy
    fn read_owner(self: @T) -> ContractAddress;

    // Storage proxy
    fn write_owner(ref self: T, owner: ContractAddress);

    // Event emission proxy
    fn emit_ownership_transferred(
        ref self: T, previous_owner: ContractAddress, new_owner: ContractAddress
    );
}

fn initializer<T, impl TOwnable: Ownable<T>, impl TDrop: Drop<T>>(
    ref self: T, owner: ContractAddress
) {
    __private::_transfer_ownership(ref self, owner);
}

fn assert_only_owner<T, impl TOwnable: Ownable<T>, impl TDrop: Drop<T>>(self: @T) {
    let owner = self.read_owner();
    let caller = get_caller_address();
    assert(caller.is_non_zero(), errors::ZERO_ADDRESS);
    assert(owner == caller, errors::NOT_OWNER);
}

fn owner<T, impl TOwnable: Ownable<T>, impl TDrop: Drop<T>>(self: @T) -> ContractAddress {
    self.read_owner()
}

fn transfer_ownership<T, impl TOwnable: Ownable<T>, impl TDrop: Drop<T>>(
    ref self: T, new_owner: ContractAddress
) {
    assert(new_owner.is_non_zero(), errors::ZERO_ADDRESS);
    assert_only_owner(@self);
    __private::_transfer_ownership(ref self, new_owner);
}

fn renounce_ownership<T, impl TOwnable: Ownable<T>, impl TDrop: Drop<T>>(ref self: T) {
    assert_only_owner(@self);
    __private::_transfer_ownership(ref self, contract_address_const::<0>());
    return ();
}

// Not public API (Cairo does not support _real_ private modules yet)
mod __private {
    use starknet::ContractAddress;

    use super::Ownable;

    fn _transfer_ownership<T, impl TOwnable: Ownable<T>, impl TDrop: Drop<T>>(
        ref self: T, new_owner: ContractAddress
    ) {
        let previous_owner = self.read_owner();
        self.write_owner(new_owner);
        self.emit_ownership_transferred(previous_owner, new_owner);
    }
}
