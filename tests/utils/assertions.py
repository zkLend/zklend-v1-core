from typing import Coroutine

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
