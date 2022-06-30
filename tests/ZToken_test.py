import pytest

from utils.account import Account, Call, deploy_account
from utils.contracts import (
    CAIRO_PATH,
    PATH_MOCK_MARKET,
    PATH_ZTOKEN,
)
from utils.helpers import string_to_felt
from utils.uint256 import Uint256

from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

MOCK_TOKEN_ADDRESS = 9999


class Setup:
    starknet: Starknet
    alice: Account
    bob: Account
    market: StarknetContract
    z_token: StarknetContract

    def __init__(
        self,
        starknet: Starknet,
        alice: Account,
        bob: Account,
        market: StarknetContract,
        z_token: StarknetContract,
    ):
        self.starknet = starknet
        self.alice = alice
        self.bob = bob
        self.market = market
        self.z_token = z_token


@pytest.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    alice = await deploy_account(starknet)
    bob = await deploy_account(starknet)

    market = await starknet.deploy(
        source=PATH_MOCK_MARKET,
        constructor_calldata=[],
        cairo_path=[CAIRO_PATH],
    )

    z_token = await starknet.deploy(
        source=PATH_ZTOKEN,
        constructor_calldata=[
            market.contract_address,  # _market
            MOCK_TOKEN_ADDRESS,  # _underlying
            string_to_felt("TOKEN_NAME"),  # _name
            string_to_felt("TOKEN_SYMBOL"),  # _symbol
            18,  # _decimals
        ],
        cairo_path=[CAIRO_PATH],
    )

    await alice.execute(
        [
            Call(
                market.contract_address,
                get_selector_from_name("set_lending_accumulator"),
                [
                    MOCK_TOKEN_ADDRESS,  # token
                    1 * 10**27,  # value
                ],
            ),
            Call(
                market.contract_address,
                get_selector_from_name("mint_z_token"),
                [
                    z_token.contract_address,  # z_token
                    alice.address,  # to
                    100 * 10**18,  # amount
                ],
            ),
            Call(
                market.contract_address,
                get_selector_from_name("set_lending_accumulator"),
                [
                    MOCK_TOKEN_ADDRESS,  # token
                    2 * 10**27,  # value
                ],
            ),
        ]
    )

    return Setup(
        starknet,
        alice,
        bob,
        market,
        z_token,
    )


@pytest.mark.asyncio
async def test_meta(setup: Setup):
    assert (await setup.z_token.name().call()).result.name == (
        string_to_felt("TOKEN_NAME")
    )
    assert (await setup.z_token.symbol().call()).result.symbol == (
        string_to_felt("TOKEN_SYMBOL")
    )
    assert (await setup.z_token.decimals().call()).result.decimals == (18)


@pytest.mark.asyncio
async def test_balance_should_scale_with_accumulator(setup: Setup):
    assert (
        await setup.z_token.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(200 * 10**18))


@pytest.mark.asyncio
async def test_approve_should_change_allowance(setup: Setup):
    assert (
        await setup.z_token.allowance(setup.alice.address, setup.bob.address).call()
    ).result.remaining == (Uint256.from_int(0))

    await setup.alice.execute(
        [
            Call(
                setup.z_token.contract_address,
                get_selector_from_name("approve"),
                [
                    setup.bob.address,  # spender
                    *Uint256.from_int(50 * 10**18),  # amount
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("set_lending_accumulator"),
                [
                    MOCK_TOKEN_ADDRESS,  # token
                    3 * 10**27,  # value
                ],
            ),
        ]
    )

    assert (
        await setup.z_token.allowance(setup.alice.address, setup.bob.address).call()
    ).result.remaining == (Uint256.from_int(50 * 10**18))


@pytest.mark.asyncio
async def test_transfer_from(setup: Setup):
    # Alice allownace for Bob: 50
    # Alice balance: 400
    await setup.alice.execute(
        [
            Call(
                setup.z_token.contract_address,
                get_selector_from_name("approve"),
                [
                    setup.bob.address,  # spender
                    *Uint256.from_int(50 * 10**18),  # amount
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("set_lending_accumulator"),
                [
                    MOCK_TOKEN_ADDRESS,  # token
                    4 * 10**27,  # value
                ],
            ),
        ]
    )

    # Bob transfers 40 from Alice
    # Balances double:
    #   Alice: (400 - 40) * 2 = 720
    #   Bob: 40 * 2 = 80
    #   Allowance: 50 - 40 = 10
    await setup.bob.execute(
        [
            Call(
                setup.z_token.contract_address,
                get_selector_from_name("transferFrom"),
                [
                    setup.alice.address,  # sender
                    setup.bob.address,  # recipient
                    *Uint256.from_int(40 * 10**18),  # amount
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("set_lending_accumulator"),
                [
                    MOCK_TOKEN_ADDRESS,  # token
                    8 * 10**27,  # value
                ],
            ),
        ]
    )

    assert (
        await setup.z_token.allowance(setup.alice.address, setup.bob.address).call()
    ).result.remaining == (Uint256.from_int(10 * 10**18))
    assert (
        await setup.z_token.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(720 * 10**18))
    assert (await setup.z_token.balanceOf(setup.bob.address).call()).result.balance == (
        Uint256.from_int(80 * 10**18)
    )


@pytest.mark.asyncio
async def test_transfer_all(setup: Setup):
    await setup.alice.execute(
        [
            Call(
                setup.z_token.contract_address,
                get_selector_from_name("transfer_all"),
                [
                    setup.bob.address,  # recipient
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("set_lending_accumulator"),
                [
                    MOCK_TOKEN_ADDRESS,  # token
                    4 * 10**27,  # value
                ],
            ),
        ]
    )

    assert (
        await setup.z_token.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(0))
    assert (await setup.z_token.balanceOf(setup.bob.address).call()).result.balance == (
        Uint256.from_int(400 * 10**18)
    )


@pytest.mark.asyncio
async def test_burn_all(setup: Setup):
    await setup.alice.execute(
        [
            Call(
                setup.market.contract_address,
                get_selector_from_name("mint_z_token"),
                [
                    setup.z_token.contract_address,  # z_token
                    setup.bob.address,  # to
                    100 * 10**18,  # amount
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("set_lending_accumulator"),
                [
                    MOCK_TOKEN_ADDRESS,  # token
                    4 * 10**27,  # value
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("burn_all_z_token"),
                [
                    setup.z_token.contract_address,  # z_token
                    setup.alice.address,  # user
                ],
            ),
        ]
    )

    assert (await setup.market.get_last_call_result().call()).result.res == (
        400 * 10**18
    )
    assert (
        await setup.z_token.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(0))
    assert (await setup.z_token.balanceOf(setup.bob.address).call()).result.balance == (
        Uint256.from_int(200 * 10**18)
    )
    assert (await setup.z_token.totalSupply().call()).result.total_supply == (
        Uint256.from_int(200 * 10**18)
    )
