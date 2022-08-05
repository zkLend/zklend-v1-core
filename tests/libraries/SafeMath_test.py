import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))

import pytest
import pytest_asyncio

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


@pytest_asyncio.fixture
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
async def test_sub_underflow(setup: Setup):
    for (a, b) in [
        (0, 1),
        (2**128, 2**250),
    ]:
        await assert_reverted_with(
            setup.safe_math.sub(a, b).call(), "SafeMath: subtraction underflow"
        )


@pytest.mark.asyncio
async def test_mul(setup: Setup):
    for (a, b, product) in [
        (2, 3, 6),
        (2**128, 2**10, 2**138),
    ]:
        assert (await setup.safe_math.mul(a, b).call()).result.res == (product)


@pytest.mark.asyncio
async def test_mul_felt_overflow(setup: Setup):
    await assert_reverted_with(
        setup.safe_math.mul(2**250 + 17 * 2**191, 3).call(),
        "SafeMath: multiplication overflow",
    )


@pytest.mark.asyncio
async def test_mul_uint256_overflow(setup: Setup):
    await assert_reverted_with(
        setup.safe_math.mul(2**250, 2**5).call(),
        "SafeCast: uint256 value out of range",
    )


@pytest.mark.asyncio
async def test_div(setup: Setup):
    for (a, b, quotient) in [
        (6, 3, 2),
        (2**138, 2**10, 2**128),
        (100, 3, 33),
    ]:
        assert (await setup.safe_math.div(a, b).call()).result.res == (quotient)


@pytest.mark.asyncio
async def test_div_division_by_zero(setup: Setup):
    await assert_reverted_with(
        setup.safe_math.div(999, 0).call(),
        "SafeMath: division by zero",
    )
