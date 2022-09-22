import pytest
import pytest_asyncio

from starkware.starknet.business_logic.execution.objects import Event

from utils.account import Account, Call, deploy_account
from utils.assertions import assert_events_emitted
from utils.contracts import (
    CAIRO_PATH,
    PATH_MOCK_MARKET,
    PATH_PROXY,
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


@pytest_asyncio.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    alice = await deploy_account(starknet)
    bob = await deploy_account(starknet)

    market = await starknet.deploy(
        source=PATH_MOCK_MARKET,
        constructor_calldata=[],
        cairo_path=[CAIRO_PATH],
    )

    z_token_cls = await starknet.declare(source=PATH_ZTOKEN, cairo_path=[CAIRO_PATH])
    z_token = await starknet.deploy(
        source=PATH_PROXY,
        constructor_calldata=[
            z_token_cls.class_hash,  # implementation_hash
            get_selector_from_name("initializer"),  # selector
            6,  # calldata_len
            999999,  # calldata: proxy_admin
            market.contract_address,  # calldata: _market
            MOCK_TOKEN_ADDRESS,  # calldata: _underlying
            string_to_felt("TOKEN_NAME"),  # calldata: _name
            string_to_felt("TOKEN_SYMBOL"),  # calldata: _symbol
            18,  # calldata: _decimals
        ],
        cairo_path=[CAIRO_PATH],
    )
    z_token = StarknetContract(
        state=z_token.state,
        abi=z_token_cls.abi,
        contract_address=z_token.contract_address,
        deploy_call_info=z_token.deploy_call_info,
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
async def test_transfer_should_emit_events(setup: Setup):
    await assert_events_emitted(
        setup.alice.execute(
            [
                Call(
                    setup.z_token.contract_address,
                    get_selector_from_name("transfer"),
                    [
                        setup.bob.address,  # recipient
                        *Uint256.from_int(50 * 10**18),  # amount
                    ],
                ),
            ]
        ),
        [
            Event(
                from_address=setup.z_token.contract_address,
                keys=[get_selector_from_name("Transfer")],
                data=[
                    setup.alice.address,  # from_
                    setup.bob.address,  # to
                    *Uint256.from_int(50 * 10**18),  # amount
                ],
            ),
            Event(
                from_address=setup.z_token.contract_address,
                keys=[get_selector_from_name("RawTransfer")],
                data=[
                    setup.alice.address,  # from_
                    setup.bob.address,  # to
                    25 * 10**18,  # raw_value
                    2 * 10**27,  # accumulator
                    50 * 10**18,  # face_value
                ],
            ),
        ],
    )


@pytest.mark.asyncio
async def test_transfer_all_should_emit_events(setup: Setup):
    await assert_events_emitted(
        setup.alice.execute(
            [
                Call(
                    setup.z_token.contract_address,
                    get_selector_from_name("transfer_all"),
                    [
                        setup.bob.address,  # recipient
                    ],
                ),
            ]
        ),
        [
            Event(
                from_address=setup.z_token.contract_address,
                keys=[get_selector_from_name("Transfer")],
                data=[
                    setup.alice.address,  # from_
                    setup.bob.address,  # to
                    *Uint256.from_int(200 * 10**18),  # amount
                ],
            ),
            Event(
                from_address=setup.z_token.contract_address,
                keys=[get_selector_from_name("RawTransfer")],
                data=[
                    setup.alice.address,  # from_
                    setup.bob.address,  # to
                    100 * 10**18,  # raw_value
                    2 * 10**27,  # accumulator
                    200 * 10**18,  # face_value
                ],
            ),
        ],
    )


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
