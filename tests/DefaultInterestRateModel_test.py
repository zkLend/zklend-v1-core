import pytest

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


@pytest.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    # slope_0: 0.1
    # slope_1: 0.5
    # y_intercept: 1%
    # optimal_rate: 60%
    model = await starknet.deploy(
        source=PATH_DEFAULT_INTEREST_RATE_MODEL,
        constructor_calldata=[
            1 * 10**26,  # slope_0
            5 * 10**26,  # slope_1
            1 * 10**25,  # y_intercept
            6 * 10**26,  # optimal_rate
        ],
        cairo_path=[CAIRO_PATH],
    )

    return Setup(starknet, model)


@pytest.mark.asyncio
async def test_borrow_rates(setup: Setup):
    for (reserve_balance, total_debt, borrow_rate) in [
        (100, 0, 1 * 10**25),  # 0% utilized: 1%
        (90, 10, 2 * 10**25),  # 10% utilized: 2%
        (50, 50, 6 * 10**25),  # 50% utilized: 6%
        (40, 60, 7 * 10**25),  # 60% utilized: 7%
        (30, 70, 12 * 10**25),  # 70% utilized: 12%
        (10, 90, 22 * 10**25),  # 90% utilized: 22%
        (0, 100, 27 * 10**25),  # 100% utilized: 27%
    ]:
        assert (
            await setup.model.get_interest_rates(reserve_balance, total_debt).call()
        ).result.borrowing_rate == (borrow_rate)
