import pytest
import pytest_asyncio

from utils.contracts import (
    CAIRO_PATH,
    PATH_DEFAULT_INTEREST_RATE_MODEL,
)

from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


class Setup:
    starknet: Starknet
    model: StarknetContract

    def __init__(self, starknet: Starknet, model: StarknetContract):
        self.starknet = starknet
        self.model = model


@pytest_asyncio.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    # slope_0: 0.1
    # slope_1: 0.5
    # y_intercept: 1%
    # optimal_rate: 80%
    model = await starknet.deploy(
        source=PATH_DEFAULT_INTEREST_RATE_MODEL,
        constructor_calldata=[
            1 * 10**26,  # slope_0
            5 * 10**26,  # slope_1
            1 * 10**25,  # y_intercept
            8 * 10**26,  # optimal_rate
        ],
        cairo_path=[CAIRO_PATH],
    )

    return Setup(starknet, model)


@pytest.mark.asyncio
async def test_borrow_rates(setup: Setup):
    for (reserve_balance, total_debt, borrow_rate) in [
        # 0% utilized: 0%
        (100, 0, 0),
        # 10% utilized:
        #   1% + 0.1 * (10% / 80%) = 2.25%
        (90, 10, 225 * 10**23),
        # 50% utilized:
        #   1% + 0.1 * (50% / 80%) = 7.25%
        (50, 50, 725 * 10**23),
        # 60% utilized:
        #   1% + 0.1 * (60% / 80%) = 8.5%
        (40, 60, 85 * 10**24),
        # 70% utilized:
        #   1% + 0.1 * (70% / 80%) = 9.75%
        (30, 70, 975 * 10**23),
        # 90% utilized:
        #   1% + 0.1 + 0.5 * (90% - 80%) / (100% - 80%) = 36%
        (10, 90, 36 * 10**25),
        # 100% utilized:
        #   1% + 0.1 + 0.5 * (100% - 80%) / (100% - 80%) = 61%
        (0, 100, 61 * 10**25),
    ]:
        assert (
            await setup.model.get_interest_rates(reserve_balance, total_debt).call()
        ).result.borrowing_rate == (borrow_rate)
