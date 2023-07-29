use array::SpanTrait;
use option::OptionTrait;
use test::test_utils::assert_eq;

use starknet::ContractAddress;

fn assert_event_emitted<
    T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>, impl TPartialEq: PartialEq<T>
>(
    contract_address: ContractAddress, key: felt252, expected_payload: @T
) {
    loop {
        let (mut keys, mut data) = starknet::testing::pop_log_raw(contract_address)
            .expect('NO_MORE_EVENTS');

        // `starknet::Event::deserialize` does NOT validate keys. We need to check it ourselves.
        assert_eq(@keys.len(), @1, 'UNEXPECTED_KEYS_SIZE');
        if keys.at(0) != @key {
            continue;
        }

        let decoded_payload: T = starknet::Event::deserialize(ref keys, ref data)
            .expect('EVENT_DESER');

        if @decoded_payload == expected_payload {
            break;
        };
    }
}

fn assert_approximatedly_equals(left: u256, right: u256, error: u256) {
    let abs = if left > right {
        left - right
    } else {
        right - left
    };
    assert(abs <= error, 'APPROXIMATE_EQUALITY_FAILED');
}
