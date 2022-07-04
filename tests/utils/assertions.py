from typing import Coroutine, List
from starkware.starknet.business_logic.execution.objects import Event

from starkware.starkware_utils.error_handling import StarkException


async def assert_reverted_with(func: Coroutine, error_message: str):
    try:
        await func
        assert False
    except StarkException as err:
        if err.message is None:
            assert False
        else:
            error_line = f"Error message: {error_message}"
            assert (
                err.message.startswith(f"{error_line}\n")
                or f"\n{error_line}\n" in err.message
            )


async def assert_events_emitted(func: Coroutine, expected_events: List[Event]):
    result = await func
    actual_events: List[Event] = result.raw_events
    for ind, expected_event in enumerate(expected_events):
        is_event_present = False

        for actual_event in actual_events:
            if (
                actual_event.from_address == expected_event.from_address
                and actual_event.keys == expected_event.keys
                and actual_event.data == expected_event.data
            ):
                is_event_present = True
                break

        assert is_event_present, f"Event at index {ind} is not emitted"
