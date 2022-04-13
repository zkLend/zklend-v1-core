from typing import Coroutine

from starkware.starkware_utils.error_handling import StarkException


async def assert_reverted_with(func: Coroutine, error_message: str):
    try:
        await func
        assert False
    except StarkException as err:
        assert f"\nError message: {error_message}\n" in err.message
