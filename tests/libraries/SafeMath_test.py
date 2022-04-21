import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))

import pytest

from utils.assertions import assert_reverted_with
from utils.contracts import CAIRO_PATH, PATH_MOCK_SAFE_MATH

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


class Setup:
    starknet: Starknet
    safe_math: StarknetContract

    def __init__(self, starknet: Starknet, safe_math: StarknetContract):
        self.starknet = starknet
        self.safe_math = safe_math


@pytest.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    safe_math = await starknet.deploy(
        source=PATH_MOCK_SAFE_MATH,
        cairo_path=[CAIRO_PATH],
    )

    return Setup(starknet, safe_math)


@pytest.mark.asyncio
async def test_add(setup: Setup):
    for (a, b, sum) in [
        (1, 2, 3),
        (2**251 + 17 * 2**192 - 1, 1, 2**251 + 17 * 2**192),
    ]:
        assert (await setup.safe_math.add(a, b).call()).result.res == (sum)


@pytest.mark.asyncio
async def test_add_overflow(setup: Setup):
    for (a, b) in [
        (2**251 + 17 * 2**192, 1),
        (2**251 + 17 * 2**192, 2**251 + 17 * 2**192),
    ]:
        await assert_reverted_with(
            setup.safe_math.add(a, b).call(), "SafeMath: addition overflow"
        )


@pytest.mark.asyncio
async def test_sub(setup: Setup):
    for (a, b, sum) in [
        (1, 2, 3),
        (2**251 + 17 * 2**192 - 1, 1, 2**251 + 17 * 2**192),
    ]:
        assert (await setup.safe_math.sub(sum, b).call()).result.res == (a)


@pytest.mark.asyncio
async def test_sub_overflow(setup: Setup):
    for (a, b) in [
        (0, 1),
        (2**128, 2**250),
    ]:
        await assert_reverted_with(
            setup.safe_math.sub(a, b).call(), "SafeMath: subtraction underflow"
        )
