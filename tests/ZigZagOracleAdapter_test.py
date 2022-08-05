import pytest
import pytest_asyncio

from utils.account import Account, Call, deploy_account
from utils.contracts import (
    CAIRO_PATH,
    PATH_MOCK_ZIG_ZAG_ORACLE,
    PATH_ZIG_ZAG_ORACLE_ADAPTER,
)

from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


class Setup:
    starknet: Starknet
    alice: Account
    adapter: StarknetContract
    oracle: StarknetContract

    def __init__(
        self,
        starknet: Starknet,
        alice: Account,
        adapter: StarknetContract,
        oracle: StarknetContract,
    ):
        self.starknet = starknet
        self.alice = alice
        self.adapter = adapter
        self.oracle = oracle


@pytest_asyncio.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    alice = await deploy_account(starknet)

    oracle = await starknet.deploy(
        source=PATH_MOCK_ZIG_ZAG_ORACLE,
        cairo_path=[CAIRO_PATH],
    )
    adapter = await starknet.deploy(
        source=PATH_ZIG_ZAG_ORACLE_ADAPTER,
        constructor_calldata=[
            oracle.contract_address,  # _oracle
        ],
        cairo_path=[CAIRO_PATH],
    )

    return Setup(starknet, alice, adapter, oracle)


@pytest.mark.asyncio
async def test_price_scale_up(setup: Setup):
    await setup.alice.execute(
        [
            Call(
                setup.oracle.contract_address,
                get_selector_from_name("set_decimals"),
                [
                    6,  # decimals
                ],
            ),
            Call(
                setup.oracle.contract_address,
                get_selector_from_name("set_price"),
                [
                    8_888000,  # price
                    100,  # update_time
                ],
            ),
        ]
    )

    assert (await setup.adapter.get_price().call()).result.price == (8_88800000)


@pytest.mark.asyncio
async def test_price_scale_down(setup: Setup):
    await setup.alice.execute(
        [
            Call(
                setup.oracle.contract_address,
                get_selector_from_name("set_decimals"),
                [
                    10,  # decimals
                ],
            ),
            Call(
                setup.oracle.contract_address,
                get_selector_from_name("set_price"),
                [
                    8_8880000000,  # price
                    100,  # update_time
                ],
            ),
        ]
    )

    assert (await setup.adapter.get_price().call()).result.price == (8_88800000)
