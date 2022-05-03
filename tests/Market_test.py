import pytest

from utils.account import Account, Call, deploy_account
from utils.assertions import assert_reverted_with
from utils.contracts import (
    CAIRO_PATH,
    PATH_DEFAULT_INTEREST_RATE_MODEL,
    PATH_ERC20,
    PATH_MARKET,
    PATH_MOCK_PRICE_ORACLE,
    PATH_ZTOKEN,
)
from utils.helpers import string_to_felt
from utils.uint256 import Uint256

from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


class Setup:
    starknet: Starknet
    alice: Account
    bob: Account
    oracle: StarknetContract
    market: StarknetContract
    token_a: StarknetContract
    z_token_a: StarknetContract
    irm_a: StarknetContract
    token_b: StarknetContract
    z_token_b: StarknetContract
    irm_b: StarknetContract

    def __init__(
        self,
        starknet: Starknet,
        alice: Account,
        bob: Account,
        oracle: StarknetContract,
        market: StarknetContract,
        token_a: StarknetContract,
        z_token_a: StarknetContract,
        irm_a: StarknetContract,
        token_b: StarknetContract,
        z_token_b: StarknetContract,
        irm_b: StarknetContract,
    ):
        self.starknet = starknet
        self.alice = alice
        self.bob = bob
        self.oracle = oracle
        self.market = market
        self.token_a = token_a
        self.z_token_a = z_token_a
        self.irm_a = irm_a
        self.token_b = token_b
        self.z_token_b = z_token_b
        self.irm_b = irm_b


@pytest.fixture
async def setup() -> Setup:
    starknet = await Starknet.empty()

    alice = await deploy_account(starknet)
    bob = await deploy_account(starknet)

    oracle = await starknet.deploy(
        source=PATH_MOCK_PRICE_ORACLE, cairo_path=[CAIRO_PATH]
    )

    market = await starknet.deploy(
        source=PATH_MARKET,
        constructor_calldata=[
            alice.address,  # owner
            oracle.contract_address,  # _oracle
        ],
        cairo_path=[CAIRO_PATH],
    )

    token_a = await starknet.deploy(
        source=PATH_ERC20,
        constructor_calldata=[
            string_to_felt("Test Token A"),  # name
            string_to_felt("TST_A"),  # symbol
            18,  # decimals
            *Uint256.from_int(10 ** (6 + 18)),  # initial_supply
            alice.address,  # recipient
        ],
        cairo_path=[CAIRO_PATH],
    )
    z_token_a = await starknet.deploy(
        source=PATH_ZTOKEN,
        constructor_calldata=[
            market.contract_address,  # _market
            token_a.contract_address,  # _underlying
            string_to_felt("zkLend Interest-Bearing TST_A"),  # _name
            string_to_felt("zTST_A"),  # _symbol
            18,  # _decimals
        ],
        cairo_path=[CAIRO_PATH],
    )
    irm_a = await starknet.deploy(
        source=PATH_DEFAULT_INTEREST_RATE_MODEL,
        constructor_calldata=[
            1 * 10**26,  # slope_0: 0.1
            5 * 10**26,  # slope_1: 0.5
            1 * 10**25,  # y_intercept: 1%
            6 * 10**26,  # optimal_rate: 60%
        ],
        cairo_path=[CAIRO_PATH],
    )

    token_b = await starknet.deploy(
        source=PATH_ERC20,
        constructor_calldata=[
            string_to_felt("Test Token B"),  # name
            string_to_felt("TST_B"),  # symbol
            18,  # decimals
            *Uint256.from_int(10 ** (6 + 18)),  # initial_supply
            bob.address,  # recipient
        ],
        cairo_path=[CAIRO_PATH],
    )
    z_token_b = await starknet.deploy(
        source=PATH_ZTOKEN,
        constructor_calldata=[
            market.contract_address,  # _market
            token_a.contract_address,  # _underlying
            string_to_felt("zkLend Interest-Bearing TST_B"),  # _name
            string_to_felt("zTST_B"),  # _symbol
            18,  # _decimals
        ],
        cairo_path=[CAIRO_PATH],
    )
    irm_b = await starknet.deploy(
        source=PATH_DEFAULT_INTEREST_RATE_MODEL,
        constructor_calldata=[
            2 * 10**26,  # slope_0: 0.2
            3 * 10**26,  # slope_1: 0.3
            0,  # y_intercept: 0%
            7 * 10**26,  # optimal_rate: 70%
        ],
        cairo_path=[CAIRO_PATH],
    )

    # TST_A: 50% collateral_factor, 80% borrow_factor
    # TST_B: 75% collateral_factor, 90% borrow_factor
    await alice.execute(
        [
            Call(
                market.contract_address,
                get_selector_from_name("add_reserve"),
                [
                    token_a.contract_address,  # token
                    z_token_a.contract_address,  # z_token
                    irm_a.contract_address,  # interest_rate_model
                    5 * 10**26,  # collateral_factor
                    8 * 10**26,  # borrow_factor
                ],
            ),
            Call(
                market.contract_address,
                get_selector_from_name("add_reserve"),
                [
                    token_b.contract_address,  # token
                    z_token_b.contract_address,  # z_token
                    irm_b.contract_address,  # interest_rate_model
                    75 * 10**25,  # collateral_factor
                    9 * 10**26,  # borrow_factor
                ],
            ),
            Call(
                oracle.contract_address,
                get_selector_from_name("set_price"),
                [
                    token_a.contract_address,  # token
                    50_00000000,  # price
                    100,  # update_time
                ],
            ),
            Call(
                oracle.contract_address,
                get_selector_from_name("set_price"),
                [
                    token_b.contract_address,  # token
                    100_00000000,  # price
                    100,  # update_time
                ],
            ),
        ]
    )

    return Setup(
        starknet,
        alice,
        bob,
        oracle,
        market,
        token_a,
        z_token_a,
        irm_a,
        token_b,
        z_token_b,
        irm_b,
    )


@pytest.mark.asyncio
async def test_token_transferred_on_deposit(setup: Setup):
    await setup.alice.execute(
        [
            Call(
                setup.token_a.contract_address,
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
                    setup.token_a.contract_address,  # token
                    10**18,  # amount
                ],
            )
        ]
    )

    assert (
        await setup.token_a.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(999_999 * 10**18))
    assert (
        await setup.token_a.balanceOf(setup.market.contract_address).call()
    ).result.balance == (Uint256.from_int(10**18))

    assert (
        await setup.z_token_a.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(10**18))
    assert (await setup.z_token_a.totalSupply().call()).result.total_supply == (
        Uint256.from_int(10**18)
    )

    # Token is set as collateral by default
    assert (
        await setup.market.get_collateral_usage(setup.alice.address).call()
    ).result.usage & (1 << 0) == 1


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
                        setup.token_a.contract_address,  # token
                        10**18,  # amount
                    ],
                )
            ]
        ),
        "ERC20: transfer amount exceeds allowance",
    )


@pytest.mark.asyncio
async def test_token_burnt_on_withdrawal(setup: Setup):
    await setup.alice.execute(
        [
            Call(
                setup.token_a.contract_address,
                get_selector_from_name("approve"),
                [
                    setup.market.contract_address,  # spender
                    *Uint256.from_int(100 * 10**18),  # amount
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("deposit"),
                [
                    setup.token_a.contract_address,  # token
                    100 * 10**18,  # amount
                ],
            ),
        ]
    )

    # Alice: 999,900 TST_A, 100 zTST_A
    assert (
        await setup.token_a.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(999_900 * 10**18))
    assert (
        await setup.z_token_a.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(100 * 10**18))

    await setup.alice.execute(
        [
            Call(
                setup.market.contract_address,
                get_selector_from_name("withdraw"),
                [
                    setup.token_a.contract_address,  # token : felt
                    25 * 10**18,  # amount
                ],
            ),
        ]
    )

    # Alice: 999,925 TST_A, 75 zTST_A
    assert (
        await setup.token_a.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(999_925 * 10**18))
    assert (
        await setup.z_token_a.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(75 * 10**18))


@pytest.mark.asyncio
async def test_borrow_token(setup: Setup):
    # Bob deposits enough TST_B for Alice to borrow
    await setup.bob.execute(
        [
            Call(
                setup.token_b.contract_address,
                get_selector_from_name("approve"),
                [
                    setup.market.contract_address,  # spender
                    *Uint256.from_int(10_000 * 10**18),  # amount
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("deposit"),
                [
                    setup.token_b.contract_address,  # token
                    10_000 * 10**18,  # amount
                ],
            ),
        ]
    )

    await setup.alice.execute(
        [
            Call(
                setup.token_a.contract_address,
                get_selector_from_name("approve"),
                [
                    setup.market.contract_address,  # spender
                    *Uint256.from_int(100 * 10**18),  # amount
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("deposit"),
                [
                    setup.token_a.contract_address,  # token
                    100 * 10**18,  # amount
                ],
            ),
        ]
    )

    # TST_A collteral: 100 TST_A * 0.5 = 2,500 USD
    # For borrowing TST_B: 2,500 * 0.9 = 2,250 USD
    # Maximum borrow: 22.5 TST_B
    await assert_reverted_with(
        setup.alice.execute(
            [
                Call(
                    setup.market.contract_address,
                    get_selector_from_name("borrow"),
                    [
                        setup.token_b.contract_address,  # token
                        226 * 10**17,  # amount
                    ],
                )
            ]
        ),
        "Market: insufficient collateral",
    )

    await setup.alice.execute(
        [
            Call(
                setup.market.contract_address,
                get_selector_from_name("borrow"),
                [
                    setup.token_b.contract_address,  # token
                    225 * 10**17,  # amount
                ],
            )
        ]
    )

    assert (
        await setup.token_b.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(225 * 10**17))

    # Borrowing rate:
    #   Utilization rate = 22.5 / 10,000 = 0.00225
    #   Borrowing rate = 0 + 0.00225 * 0.2 = 0.00045 => 45 * 10 ** 22
    # Lending rate:
    #   Lending rate = 0.00045 * 0.00225 = 0.0000010125 => 10125 * 10 ** 17
    reserve_data = (
        await setup.market.get_reserve_data(setup.token_b.contract_address).call()
    ).result.data
    assert reserve_data.current_lending_rate == 10125 * 10**17
    assert reserve_data.current_borrowing_rate == 45 * 10**22
