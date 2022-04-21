import pytest

from utils.account import Account, Call, deploy_account
from utils.assertions import assert_reverted_with
from utils.contracts import CAIRO_PATH, PATH_ERC20, PATH_MARKET, PATH_ZTOKEN
from utils.helpers import string_to_felt
from utils.uint256 import Uint256

from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


class Setup:
    starknet: Starknet
    alice: Account
    market: StarknetContract
    token: StarknetContract
    z_token: StarknetContract

    def __init__(
        self,
        starknet: Starknet,
        alice: Account,
        market: StarknetContract,
        token: StarknetContract,
        z_token: StarknetContract,
    ):
        self.starknet = starknet
        self.alice = alice
        self.market = market
        self.token = token
        self.z_token = z_token


@pytest.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    alice = await deploy_account(starknet)

    market = await starknet.deploy(
        source=PATH_MARKET,
        constructor_calldata=[
            alice.address,  # owner
        ],
        cairo_path=[CAIRO_PATH],
    )
    token = await starknet.deploy(
        source=PATH_ERC20,
        constructor_calldata=[
            string_to_felt("Test Token"),  # name
            string_to_felt("TST"),  # symbol
            18,  # decimals
            *Uint256.from_int(10 ** (6 + 18)),  # initial_supply
            alice.address,  # recipient
        ],
        cairo_path=[CAIRO_PATH],
    )
    z_token = await starknet.deploy(
        source=PATH_ZTOKEN,
        constructor_calldata=[
            market.contract_address,  # _market
            token.contract_address,  # _underlying
            string_to_felt("zkLend Interest-Bearing TST"),  # _name
            string_to_felt("zTST"),  # _symbol
            18,  # _decimals
        ],
        cairo_path=[CAIRO_PATH],
    )

    await alice.execute(
        [
            Call(
                market.contract_address,
                get_selector_from_name("add_reserve"),
                [
                    token.contract_address,  # token
                    z_token.contract_address,  # z_token
                ],
            )
        ]
    )

    return Setup(
        starknet,
        alice,
        market,
        token,
        z_token,
    )


@pytest.mark.asyncio
async def test_token_transferred_on_deposit(setup: Setup):
    await setup.alice.execute(
        [
            Call(
                setup.token.contract_address,
                get_selector_from_name("approve"),
                [
                    setup.market.contract_address,  # spender
                    *Uint256.from_int(10**18),  # amount
                ],
            )
        ]
    )
    await setup.alice.execute(
        [
            Call(
                setup.market.contract_address,
                get_selector_from_name("deposit"),
                [
                    setup.token.contract_address,  # token : felt
                    10**18,  # amount
                ],
            )
        ]
    )

    assert (await setup.token.balanceOf(setup.alice.address).call()).result.balance == (
        Uint256.from_int(999_999 * 10**18)
    )
    assert (
        await setup.token.balanceOf(setup.market.contract_address).call()
    ).result.balance == (Uint256.from_int(10**18))


@pytest.mark.asyncio
async def test_deposit_transfer_failed(setup: Setup):
    # transferFrom fails due to insufficient allowance
    await assert_reverted_with(
        setup.alice.execute(
            [
                Call(
                    setup.market.contract_address,
                    get_selector_from_name("deposit"),
                    [
                        setup.token.contract_address,  # token : felt
                        10**18,  # amount
                    ],
                )
            ]
        ),
        "ERC20: transfer amount exceeds allowance",
    )
