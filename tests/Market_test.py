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

from starkware.starknet.business_logic.state.state import BlockInfo
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
            token_b.contract_address,  # _underlying
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


@pytest.fixture
async def setup_with_loan(setup: Setup) -> Setup:
    # Same as `test_borrow_token`
    await setup.bob.execute(
        [
            Call(
                setup.token_b.contract_address,
                get_selector_from_name("approve"),
                [
                    setup.market.contract_address,  # spender
                    *Uint256.from_int(1_000_000 * 10**18),  # amount
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
            Call(
                setup.market.contract_address,
                get_selector_from_name("borrow"),
                [
                    setup.token_b.contract_address,  # token
                    225 * 10**17,  # amount
                ],
            ),
        ]
    )

    return setup


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
                    *Uint256.from_int(1_000 * 10**18),  # amount
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

    # Cannot borrow anymore with existing collateral
    await assert_reverted_with(
        setup.alice.execute(
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
        ),
        "Market: insufficient collateral",
    )

    # Cannot withdraw collateral
    await assert_reverted_with(
        setup.alice.execute(
            [
                Call(
                    setup.market.contract_address,
                    get_selector_from_name("withdraw"),
                    [
                        setup.token_a.contract_address,  # token
                        10 * 10**18,  # amount
                    ],
                )
            ]
        ),
        "Market: insufficient collateral",
    )

    # Alice borrows more with more collateral
    await setup.alice.execute(
        [
            Call(
                setup.market.contract_address,
                get_selector_from_name("deposit"),
                [
                    setup.token_a.contract_address,  # token
                    100 * 10**18,  # amount
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("borrow"),
                [
                    setup.token_b.contract_address,  # token
                    225 * 10**17,  # amount
                ],
            ),
        ]
    )

    assert (
        await setup.token_b.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(45 * 10**18))

    # Borrowing rate:
    #   Utilization rate = 45 / 10,000 = 0.0045
    #   Borrowing rate = 0 + 0.0045 * 0.2 = 0.0009 => 9 * 10 ** 23
    # Lending rate:
    #   Lending rate = 0.0009 * 0.0045 = 0.00000405 => 405 * 10 ** 19
    reserve_data = (
        await setup.market.get_reserve_data(setup.token_b.contract_address).call()
    ).result.data
    assert reserve_data.current_lending_rate == 405 * 10**19
    assert reserve_data.current_borrowing_rate == 9 * 10**23


@pytest.mark.asyncio
async def test_rate_changes_on_deposit(setup_with_loan: Setup):
    setup = setup_with_loan

    # Bob deposits another 5,000 TST_B
    await setup.bob.execute(
        [
            Call(
                setup.market.contract_address,
                get_selector_from_name("deposit"),
                [
                    setup.token_b.contract_address,  # token
                    5_000 * 10**18,  # amount
                ],
            ),
        ]
    )

    # Borrowing rate:
    #   Utilization rate = 22.5 / 15,000 = 0.0015
    #   Borrowing rate = 0 + 0.0015 * 0.2 = 0.0003 => 3 * 10 ** 23
    # Lending rate:
    #   Lending rate = 0.0003 * 0.0015 = 0.00000045 => 45 * 10 ** 19
    reserve_data = (
        await setup.market.get_reserve_data(setup.token_b.contract_address).call()
    ).result.data
    assert reserve_data.current_lending_rate == 45 * 10**19
    assert reserve_data.current_borrowing_rate == 3 * 10**23


@pytest.mark.asyncio
async def test_rate_changes_on_withdrawal(setup_with_loan: Setup):
    setup = setup_with_loan

    # Bob withdraws 5,000 TST_B
    await setup.bob.execute(
        [
            Call(
                setup.market.contract_address,
                get_selector_from_name("withdraw"),
                [
                    setup.token_b.contract_address,  # token
                    5_000 * 10**18,  # amount
                ],
            ),
        ]
    )

    # Borrowing rate:
    #   Utilization rate = 22.5 / 5,000 = 0.0045
    #   Borrowing rate = 0 + 0.0045 * 0.2 = 0.0009 => 9 * 10 ** 23
    # Lending rate:
    #   Lending rate = 0.0009 * 0.0045 = 0.00000405 => 405 * 10 ** 19
    reserve_data = (
        await setup.market.get_reserve_data(setup.token_b.contract_address).call()
    ).result.data
    assert reserve_data.current_lending_rate == 405 * 10**19
    assert reserve_data.current_borrowing_rate == 9 * 10**23


@pytest.mark.asyncio
async def test_interest_accumulation(setup_with_loan: Setup):
    # No interest accumulated yet
    assert (
        await setup_with_loan.z_token_b.balanceOf(setup_with_loan.bob.address).call()
    ).result.balance == (Uint256.from_int(10000 * 10**18))

    setup_with_loan.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup_with_loan.starknet.state.state.block_info.block_number,
        100,
    )

    # Interest after 100 seconds:
    #   Interest = 0.0000010125 * 10000 * 100 / (365 * 86400) = 0.000000032106164383561643835
    #                                                         => 32106164383
    #   Total balance = 10000 * 10 ** 18 + 32106164383
    assert (
        await setup_with_loan.z_token_b.balanceOf(setup_with_loan.bob.address).call()
    ).result.balance == (Uint256.from_int(10000 * 10**18 + 32106164383))


@pytest.mark.asyncio
async def test_debt_accumulation(setup_with_loan: Setup):
    # No interest accumulated yet
    assert (
        await setup_with_loan.market.get_user_debt_for_token(
            setup_with_loan.alice.address, setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (225 * 10**17)

    setup_with_loan.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup_with_loan.starknet.state.state.block_info.block_number,
        100,
    )

    # Interest after 100 seconds:
    #   Interest = 0.00045 * 22.5 * 100 / (365 * 86400) = 0.000000032106164383
    #                                                   => 32106164383
    #   Total debt = 22.5 * 10 ** 18 + 32106164383
    assert (
        await setup_with_loan.market.get_user_debt_for_token(
            setup_with_loan.alice.address, setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (225 * 10**17 + 32106164383)
    assert (
        await setup_with_loan.market.get_total_debt_for_token(
            setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (225 * 10**17 + 32106164383)


@pytest.mark.asyncio
async def test_no_debt_accumulation_without_loan(setup: Setup):
    # Alice deposits token A
    await setup.alice.execute(
        [
            Call(
                setup.token_a.contract_address,
                get_selector_from_name("approve"),
                [
                    setup.market.contract_address,  # spender
                    *Uint256.from_int(1_000_000 * 10**18),  # amount
                ],
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("deposit"),
                [
                    setup.token_a.contract_address,  # token
                    10_000 * 10**18,  # amount
                ],
            ),
        ]
    )

    # No interest accumulated yet
    assert (
        await setup.market.get_debt_accumulator(setup.token_a.contract_address).call()
    ).result.res == (10**27)

    setup.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup.starknet.state.state.block_info.block_number,
        100,
    )

    # Still no accumulation after 100 seconds

    assert (
        await setup.market.get_debt_accumulator(setup.token_a.contract_address).call()
    ).result.res == (10**27)


@pytest.mark.asyncio
async def test_debt_repayment(setup_with_loan: Setup):
    # Total debt is 22.500000032106164383 (based on `test_debt_accumulation`)
    setup_with_loan.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup_with_loan.starknet.state.state.block_info.block_number,
        100,
    )

    # Alice repays 1 TST_B
    await setup_with_loan.alice.execute(
        [
            Call(
                setup_with_loan.token_b.contract_address,
                get_selector_from_name("approve"),
                [
                    setup_with_loan.market.contract_address,  # spender
                    *Uint256.from_int(1 * 10**18),  # amount
                ],
            ),
            Call(
                setup_with_loan.market.contract_address,
                get_selector_from_name("repay"),
                [
                    setup_with_loan.token_b.contract_address,  # token
                    1 * 10**18,  # amount
                ],
            ),
        ]
    )

    # Off by one due to rounding error
    #   Expected: 21500000032106164383
    #   Actual  : 21500000032106164384
    assert (
        await setup_with_loan.market.get_user_debt_for_token(
            setup_with_loan.alice.address, setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (21500000032106164384)
    assert (
        await setup_with_loan.market.get_total_debt_for_token(
            setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (21500000032106164384)
    assert (
        await setup_with_loan.token_b.balanceOf(setup_with_loan.alice.address).call()
    ).result.balance == (Uint256.from_int(215 * 10**17))
    assert (
        await setup_with_loan.token_b.balanceOf(
            setup_with_loan.market.contract_address
        ).call()
    ).result.balance == (Uint256.from_int(99785 * 10**17))

    # Interest rates after repayment
    #   Borrowing rate:
    #     Utilization rate = 21.500000032106164384 / 10,000.000000032106164384
    #                      = 0.002150000003203713613047154
    #     Borrowing rate = 0 + 0.002150000003203713613047154 * 0.2
    #                    = 0.000430000000640742722609430
    #   Lending rate:
    #     Lending rate = 0.000430000000640742722609430 * 0.002150000003203713613047154
    #                  = 0.000000924500002755193709273
    reserve_data = (
        await setup_with_loan.market.get_reserve_data(
            setup_with_loan.token_b.contract_address
        ).call()
    ).result.data
    assert reserve_data.current_lending_rate == 924500002755193709273
    assert reserve_data.current_borrowing_rate == 430000000640742722609430


@pytest.mark.asyncio
async def test_liquidation(setup_with_loan: Setup):
    # Alice status now:
    #   Collateral value:
    #     100 TST_A
    #       = 100 * 50 * 0.5
    #       = 2500 USD
    #   Collateral required:
    #     22.5 TST_B
    #       = 22.5 * 100 / 0.9
    #       = 2500 USD

    # Cannot liquidate now as Alice is not undercollateralized
    await assert_reverted_with(
        setup_with_loan.bob.execute(
            [
                Call(
                    setup_with_loan.market.contract_address,
                    get_selector_from_name("liquidate"),
                    [
                        setup_with_loan.alice.address,  # user
                        setup_with_loan.token_b.contract_address,  # debt_token
                        1 * 10**18,  # amount
                        setup_with_loan.token_a.contract_address,  # collateral_token
                    ],
                ),
            ]
        ),
        "Market: invalid liquidation",
    )

    # Change TST_A price to 40 USD
    #   Collateral value:
    #     100 TST_A
    #       = 100 * 40 * 0.5
    #       = 2000 USD
    #   Collateral required: 2500 USD
    await setup_with_loan.alice.execute(
        [
            Call(
                setup_with_loan.oracle.contract_address,
                get_selector_from_name("set_price"),
                [
                    setup_with_loan.token_a.contract_address,  # token
                    40_00000000,  # price
                    100,  # update_time
                ],
            ),
        ]
    )

    # Repay maximum x TST_B:
    #   Collateral withdrawn:
    #     x * 100 / 40 TST_A
    #   Collateral value after:
    #     (100 - x * 100 / 40) TST_A
    #       = (100 - x * 100 / 40) * 40 * 0.5
    #   Collateral required:
    #     (22.5 - x) TST_B
    #       = (22.5 - x) * 100 / 0.9
    #   Collateral value after = Collateral required
    #     Solve for x
    #       x = 8.181818181818181818

    # Liquidating 8.2 TST_B is not allowed as it exceeds maximum
    await assert_reverted_with(
        setup_with_loan.bob.execute(
            [
                Call(
                    setup_with_loan.market.contract_address,
                    get_selector_from_name("liquidate"),
                    [
                        setup_with_loan.alice.address,  # user
                        setup_with_loan.token_b.contract_address,  # debt_token
                        82 * 10**17,  # amount
                        setup_with_loan.token_a.contract_address,  # collateral_token
                    ],
                ),
            ]
        ),
        "Market: invalid liquidation",
    )

    # Liquidating 8.1 TST_B works
    await setup_with_loan.bob.execute(
        [
            Call(
                setup_with_loan.market.contract_address,
                get_selector_from_name("liquidate"),
                [
                    setup_with_loan.alice.address,  # user
                    setup_with_loan.token_b.contract_address,  # debt_token
                    81 * 10**17,  # amount
                    setup_with_loan.token_a.contract_address,  # collateral_token
                ],
            ),
        ]
    )

    # Bob balances after:
    #   TST_A (Z):
    #     8.1 * 100 / 40 = 20.25 TST_A
    #   TST_B:
    #     1,000,000 - 10,000 - 8.1 = 989991.9 TST_B
    assert (
        await setup_with_loan.z_token_a.balanceOf(setup_with_loan.bob.address).call()
    ).result.balance == (Uint256.from_int(2025 * 10**16))
    assert (
        await setup_with_loan.token_b.balanceOf(setup_with_loan.bob.address).call()
    ).result.balance == (Uint256.from_int(9899919 * 10**17))

    # Alice:
    #   Debt:
    #     22.5 - 8.1 = 14.4 TST_B
    #   TST_A (Z):
    #     100 - 20.25 = 79.75 TST_A
    assert (
        await setup_with_loan.market.get_user_debt_for_token(
            setup_with_loan.alice.address, setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (144 * 10**17)
    assert (
        await setup_with_loan.market.get_total_debt_for_token(
            setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (144 * 10**17)
    assert (
        await setup_with_loan.z_token_a.balanceOf(setup_with_loan.alice.address).call()
    ).result.balance == (Uint256.from_int(7975 * 10**16))
