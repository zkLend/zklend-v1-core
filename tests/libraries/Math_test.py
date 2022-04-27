import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))

import pytest

from utils.contracts import CAIRO_PATH, PATH_MOCK_MATH

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


class Setup:
    starknet: Starknet
    math: StarknetContract

    def __init__(self, starknet: Starknet, math: StarknetContract):
        self.starknet = starknet
        self.math = math


@pytest.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    math = await starknet.deploy(
        source=PATH_MOCK_MATH,
        cairo_path=[CAIRO_PATH],
    )

    return Setup(starknet, math)


@pytest.mark.asyncio
async def test_shl(setup: Setup):
    for (a, b, res) in [
        (0, 100, 0),
        (2, 1, 2 << 1),
        (2**50 + 2**40 + 1, 45, (2**50 + 2**40 + 1) << 45),
        (2**251, 0, 0),
        (2**50 + 2**40 + 1, 210, 2**250 + 2**210),
    ]:
        assert (await setup.math.shl(a, b).call()).result.res == (res)


@pytest.mark.asyncio
async def test_shr(setup: Setup):
    for (a, b, res) in [
        (0, 100, 0),
        (2, 1, 1),
        (2**50 + 2**40 + 1, 45, 2**5),
        (2**251 + 17 * 2**192, 100, 2**151 + 17 * 2**92),
        (2**251 + 17 * 2**192, 251, 1),
        (2**251 + 17 * 2**192, 252, 0),
    ]:
        assert (await setup.math.shr(a, b).call()).result.res == (res)
