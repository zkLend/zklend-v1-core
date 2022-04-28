import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))

import pytest

from utils.assertions import assert_reverted_with
from utils.contracts import CAIRO_PATH, PATH_MOCK_SAFE_DECIMAL_MATH

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


class Setup:
    starknet: Starknet
    safe_decimal_math: StarknetContract

    def __init__(self, starknet: Starknet, safe_decimal_math: StarknetContract):
        self.starknet = starknet
        self.safe_decimal_math = safe_decimal_math


@pytest.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    safe_decimal_math = await starknet.deploy(
        source=PATH_MOCK_SAFE_DECIMAL_MATH,
        cairo_path=[CAIRO_PATH],
    )

    return Setup(starknet, safe_decimal_math)


@pytest.mark.asyncio
async def test_mul(setup: Setup):
    for (a, b, product) in [
        (10, 2 * 10**27, 20),
    ]:
        assert (await setup.safe_decimal_math.mul(a, b).call()).result.res == (product)
        assert (
            await setup.safe_decimal_math.mul_decimals(a, b, 27).call()
        ).result.res == (product)


@pytest.mark.asyncio
async def test_mul_overflow(setup: Setup):
    await assert_reverted_with(
        setup.safe_decimal_math.mul(2**250, 2 * 10**27).call(),
        "SafeMath: multiplication overflow",
    )
    await assert_reverted_with(
        setup.safe_decimal_math.mul_decimals(2**250, 2 * 10**27, 27).call(),
        "SafeMath: multiplication overflow",
    )


@pytest.mark.asyncio
async def test_div(setup: Setup):
    for (a, b, quotient) in [
        (10, 2 * 10**27, 5),
    ]:
        assert (await setup.safe_decimal_math.div(a, b).call()).result.res == (quotient)
