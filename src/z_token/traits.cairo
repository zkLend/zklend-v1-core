use starknet::ContractAddress;
use starknet::event::EventEmitter;

// Hack to simulate the `crate` keyword
use super::super as crate;

use crate::libraries::ownable;

use super::ZToken as contract;

use contract::ContractState;

// These are hacks that depend on compiler implementation details :(
// But they're needed for refactoring the contract code into modules like this one.
use contract::Ownable_ownerContractMemberStateTrait;

impl ZTokenOwnable of ownable::Ownable<ContractState> {
    fn read_owner(self: @ContractState) -> ContractAddress {
        self.Ownable_owner.read()
    }

    fn write_owner(ref self: ContractState, owner: ContractAddress) {
        self.Ownable_owner.write(owner);
    }

    fn emit_ownership_transferred(
        ref self: ContractState, previous_owner: ContractAddress, new_owner: ContractAddress
    ) {
        self
            .emit(
                contract::Event::OwnershipTransferred(
                    contract::OwnershipTransferred { previous_owner, new_owner }
                )
            );
    }
}
