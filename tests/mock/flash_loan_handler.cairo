#[starknet::contract]
mod FlashLoanHandler {
    use array::ArrayTrait;
    use option::OptionTrait;
    use traits::Into;

    use starknet::{ContractAddress, get_contract_address};

    use zklend::interfaces::{IMarketDispatcher, IMarketDispatcherTrait, IZklendFlashCallback};

    use super::super::{IERC20Dispatcher, IERC20DispatcherTrait, IFlashLoanHandler};

    #[storage]
    struct Storage {}

    #[derive(Drop, Serde)]
    struct CallbackParams {
        token: ContractAddress,
        market_addr: ContractAddress,
        return_amount: felt252
    }

    #[external(v0)]
    impl IZklendFlashCallbackImpl of IZklendFlashCallback<ContractState> {
        // IMPORANT: in a real contract, ALWAYS check the callback is being called from the real
        //           market contract! We're encoding the market address into callback data for
        //           simplicity only (avoid having to handle storage in a mock contract).
        fn zklend_flash_callback(
            ref self: ContractState, initiator: ContractAddress, mut calldata: Span::<felt252>
        ) {
            // IMPORTANT: always check the initiator is a contract you trust, similar to how it's
            //            done here.
            let this_address = get_contract_address();
            assert(initiator == this_address, 'NOT_INITIATED_BY_TRUSTED');

            let params = Serde::<CallbackParams>::deserialize(ref calldata)
                .expect('CANNOT_DECODE_PARAMS');

            IERC20Dispatcher {
                contract_address: params.token
            }.transfer(params.market_addr, params.return_amount.into());
        }
    }

    #[external(v0)]
    impl IFlashLoanHandlerImpl of IFlashLoanHandler<ContractState> {
        fn take_flash_loan(
            ref self: ContractState,
            market_addr: ContractAddress,
            token: ContractAddress,
            amount: felt252,
            return_amount: felt252
        ) {
            let this_address = get_contract_address();

            let mut calldata = array![];
            Serde::<CallbackParams>::serialize(
                @CallbackParams { token, market_addr, return_amount }, ref calldata
            );

            IMarketDispatcher {
                contract_address: market_addr
            }
                .flash_loan(
                    this_address, // receiver
                    token, // token
                    amount, // amount
                    calldata.span() // calldata
                );
        }
    }
}
