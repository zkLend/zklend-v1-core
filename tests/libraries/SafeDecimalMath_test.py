import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))

import pytest

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
async def test_div(setup: Setup):
    for (a, b, quotient) in [
        (10, 2 * 10**27, 5),
    ]:
        assert (await setup.safe_decimal_math.div(a, b).call()).result.res == (quotient)
