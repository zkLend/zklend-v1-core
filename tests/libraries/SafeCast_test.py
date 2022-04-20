import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))

import pytest
import pytest_asyncio

from utils.contracts import CAIRO_PATH, PATH_MOCK_SAFE_CAST
from utils.uint256 import Uint256

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


class Setup:
    starknet: Starknet
    safe_cast: StarknetContract

    def __init__(self, starknet: Starknet, safe_cast: StarknetContract):
        self.starknet = starknet
        self.safe_cast = safe_cast


@pytest_asyncio.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    safe_cast = await starknet.deploy(
        source=PATH_MOCK_SAFE_CAST,
        cairo_path=[CAIRO_PATH],
    )

    return Setup(starknet, safe_cast)


@pytest.mark.asyncio
async def test_felt_to_uint256(setup: Setup):
    for num in [2**128 - 1, 2**128, 2**128 + 1]:
        assert (await setup.safe_cast.felt_to_uint256(num).call()).result.res == (
            Uint256.from_int(num)
        )
