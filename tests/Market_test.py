import pytest
import pytest_asyncio

from utils.account import Account, Call, deploy_account
from utils.assertions import assert_events_emitted, assert_reverted_with
from utils.contracts import (
    CAIRO_PATH,
    PATH_DEFAULT_INTEREST_RATE_MODEL,
    PATH_ERC20,
    PATH_FLASH_LOAN_HANDLER,
    PATH_MARKET,
    PATH_MOCK_PRICE_ORACLE,
    PATH_PROXY,
    PATH_ZTOKEN,
)
from utils.helpers import string_to_felt
from utils.uint256 import Uint256

from starkware.starknet.business_logic.execution.objects import Event
from starkware.starknet.business_logic.state.state import BlockInfo
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

# TODO: add test cases for:
# - rate changes after calling `withdraw_all` when there're aother debt & deposit holders
# - rate changes after calling `repay_all` when there're aother debt & deposit holders

MOCK_TREASURY_ADDRESS = 9999888899998888


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


@pytest_asyncio.fixture
async def pre_setup() -> Setup:
    starknet = await Starknet.empty()

    alice = await deploy_account(starknet)
    bob = await deploy_account(starknet)

    oracle = await starknet.deploy(
        source=PATH_MOCK_PRICE_ORACLE, cairo_path=[CAIRO_PATH]
    )

    market_cls = await starknet.declare(source=PATH_MARKET, cairo_path=[CAIRO_PATH])
    z_token_cls = await starknet.declare(source=PATH_ZTOKEN, cairo_path=[CAIRO_PATH])

    market = await starknet.deploy(
        source=PATH_PROXY,
        constructor_calldata=[
            market_cls.class_hash,  # implementation_hash
            get_selector_from_name("initializer"),  # selector
            2,  # calldata_len
            alice.address,  # calldata: owner
            oracle.contract_address,  # calldata: _oracle
        ],
        cairo_path=[CAIRO_PATH],
    )
    market = StarknetContract(
        state=market.state,
        abi=market_cls.abi,
        contract_address=market.contract_address,
        deploy_execution_info=market.deploy_execution_info,
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
        source=PATH_PROXY,
        constructor_calldata=[
            z_token_cls.class_hash,  # implementation_hash
            get_selector_from_name("initializer"),  # selector
            6,  # calldata_len
            999999,  # calldata: proxy_admin
            market.contract_address,  # calldata: _market
            token_a.contract_address,  # calldata: _underlying
            string_to_felt("zkLend Interest-Bearing TST_A"),  # calldata: _name
            string_to_felt("zTST_A"),  # calldata: _symbol
            18,  # calldata: _decimals
        ],
        cairo_path=[CAIRO_PATH],
    )
    z_token_a = StarknetContract(
        state=z_token_a.state,
        abi=z_token_cls.abi,
        contract_address=z_token_a.contract_address,
        deploy_execution_info=z_token_a.deploy_execution_info,
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
        source=PATH_PROXY,
        constructor_calldata=[
            z_token_cls.class_hash,  # implementation_hash
            get_selector_from_name("initializer"),  # selector
            6,  # calldata_len
            999999,  # calldata: proxy_admin
            market.contract_address,  # calldata: _market
            token_b.contract_address,  # calldata: _underlying
            string_to_felt("zkLend Interest-Bearing TST_B"),  # calldata: _name
            string_to_felt("zTST_B"),  # calldata: _symbol
            18,  # calldata: _decimals
        ],
        cairo_path=[CAIRO_PATH],
    )
    z_token_b = StarknetContract(
        state=z_token_b.state,
        abi=z_token_cls.abi,
        contract_address=z_token_b.contract_address,
        deploy_execution_info=z_token_b.deploy_execution_info,
    )
    irm_b = await starknet.deploy(
        source=PATH_DEFAULT_INTEREST_RATE_MODEL,
        constructor_calldata=[
            2 * 10**26,  # slope_0: 0.2
            3 * 10**26,  # slope_1: 0.3
            5 * 10**25,  # y_intercept: 5%
            8 * 10**26,  # optimal_rate: 80%
        ],
        cairo_path=[CAIRO_PATH],
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


@pytest_asyncio.fixture
async def setup(pre_setup: Setup) -> Setup:
    # TST_A: 50% collateral_factor, 80% borrow_factor
    # TST_B: 75% collateral_factor, 90% borrow_factor
    await pre_setup.alice.execute(
        [
            Call(
                pre_setup.market.contract_address,
                get_selector_from_name("set_treasury"),
                [
                    MOCK_TREASURY_ADDRESS,  # new_treasury
                ],
            ),
            Call(
                pre_setup.market.contract_address,
                get_selector_from_name("add_reserve"),
                [
                    pre_setup.token_a.contract_address,  # token
                    pre_setup.z_token_a.contract_address,  # z_token
                    pre_setup.irm_a.contract_address,  # interest_rate_model
                    5 * 10**26,  # collateral_factor
                    8 * 10**26,  # borrow_factor
                    10 * 10**25,  # reserve_factor
                    5 * 10**25,  # flash_loan_fee
                ],
            ),
            Call(
                pre_setup.market.contract_address,
                get_selector_from_name("add_reserve"),
                [
                    pre_setup.token_b.contract_address,  # token
                    pre_setup.z_token_b.contract_address,  # z_token
                    pre_setup.irm_b.contract_address,  # interest_rate_model
                    75 * 10**25,  # collateral_factor
                    9 * 10**26,  # borrow_factor
                    20 * 10**25,  # reserve_factor
                    1 * 10**25,  # flash_loan_fee
                ],
            ),
            Call(
                pre_setup.oracle.contract_address,
                get_selector_from_name("set_price"),
                [
                    pre_setup.token_a.contract_address,  # token
                    50_00000000,  # price
                    100,  # update_time
                ],
            ),
            Call(
                pre_setup.oracle.contract_address,
                get_selector_from_name("set_price"),
                [
                    pre_setup.token_b.contract_address,  # token
                    100_00000000,  # price
                    100,  # update_time
                ],
            ),
        ]
    )

    return pre_setup


@pytest_asyncio.fixture
async def setup_with_deposit(setup: Setup) -> Setup:
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
                get_selector_from_name("enable_collateral"),
                [
                    setup.token_a.contract_address,  # token
                ],
            ),
        ]
    )

    return setup


@pytest_asyncio.fixture
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
            Call(
                setup.market.contract_address,
                get_selector_from_name("enable_collateral"),
                [
                    setup.token_b.contract_address,  # token
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
                get_selector_from_name("enable_collateral"),
                [
                    setup.token_a.contract_address,  # token
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
async def test_new_reserve_event(pre_setup: Setup):
    await assert_events_emitted(
        pre_setup.alice.execute(
            [
                Call(
                    pre_setup.market.contract_address,
                    get_selector_from_name("add_reserve"),
                    [
                        pre_setup.token_a.contract_address,  # token
                        pre_setup.z_token_a.contract_address,  # z_token
                        pre_setup.irm_a.contract_address,  # interest_rate_model
                        5 * 10**26,  # collateral_factor
                        8 * 10**26,  # borrow_factor
                        10 * 10**25,  # reserve_factor
                        5 * 10**25,  # flash_loan_fee
                    ],
                ),
            ]
        ),
        [
            Event(
                from_address=pre_setup.market.contract_address,
                keys=[get_selector_from_name("NewReserve")],
                data=[
                    pre_setup.token_a.contract_address,  # token
                    pre_setup.z_token_a.contract_address,  # z_token
                    18,  # decimals
                    pre_setup.irm_a.contract_address,  # interest_rate_model
                    5 * 10**26,  # collateral_factor
                    8 * 10**26,  # borrow_factor
                    10 * 10**25,  # reserve_factor
                    5 * 10**25,  # flash_loan_fee
                ],
            ),
        ],
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
            ),
            Call(
                setup.market.contract_address,
                get_selector_from_name("enable_collateral"),
                [
                    setup.token_a.contract_address,  # token
                ],
            ),
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
                ),
                Call(
                    setup.market.contract_address,
                    get_selector_from_name("enable_collateral"),
                    [
                        setup.token_a.contract_address,  # token
                    ],
                ),
            ]
        ),
        "ERC20: insufficient allowance",
    )


@pytest.mark.asyncio
async def test_cannot_withdraw_with_zero_amount(setup_with_deposit: Setup):
    setup = setup_with_deposit

    await assert_reverted_with(
        setup.alice.execute(
            [
                Call(
                    setup.market.contract_address,
                    get_selector_from_name("withdraw"),
                    [
                        setup.token_a.contract_address,  # token : felt
                        0,  # amount
                    ],
                ),
            ]
        ),
        "Market: zero amount",
    )


@pytest.mark.asyncio
async def test_token_burnt_on_withdrawal(setup_with_deposit: Setup):
    setup = setup_with_deposit

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

    await setup.alice.execute(
        [
            Call(
                setup.market.contract_address,
                get_selector_from_name("withdraw_all"),
                [
                    setup.token_a.contract_address,  # token : felt
                ],
            ),
        ]
    )

    # Alice: 1,000,000 TST_A, 0 zTST_A
    assert (
        await setup.token_a.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(1_000_000 * 10**18))
    assert (
        await setup.z_token_a.balanceOf(setup.alice.address).call()
    ).result.balance == (Uint256.from_int(0))


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
            Call(
                setup.market.contract_address,
                get_selector_from_name("enable_collateral"),
                [
                    setup.token_b.contract_address,  # token
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
            Call(
                setup.market.contract_address,
                get_selector_from_name("enable_collateral"),
                [
                    setup.token_a.contract_address,  # token
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
    #   Borrowing rate = 0.05 + 0.2 * 0.00225 / 0.8 = 0.0505625 => 505625 * 10 ** 20
    # Lending rate:
    #   Lending rate = 0.0505625 * 0.00225 = 0.000113765625 => 113765625 * 10 ** 15
    reserve_data = (
        await setup.market.get_reserve_data(setup.token_b.contract_address).call()
    ).result.data
    assert reserve_data.current_lending_rate == 113765625 * 10**15
    assert reserve_data.current_borrowing_rate == 505625 * 10**20

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

    # Cannot withdraw or transfer collateral
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
    await assert_reverted_with(
        setup.alice.execute(
            [
                Call(
                    setup.z_token_a.contract_address,
                    get_selector_from_name("transfer"),
                    [
                        setup.token_a.contract_address,  # recipient
                        *Uint256.from_int(10 * 10**18),  # amount
                    ],
                )
            ]
        ),
        "ZToken: invalid collateralization after transfer",
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
                get_selector_from_name("enable_collateral"),
                [
                    setup.token_a.contract_address,  # token
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
    #   Borrowing rate = 0.05 + 0.2 * 0.0045 / 0.8 = 0.051125 => 51125 * 10 ** 21
    # Lending rate:
    #   Lending rate = 0.051125 * 0.0045 = 0.0002300625 => 2300625 * 10 ** 17
    reserve_data = (
        await setup.market.get_reserve_data(setup.token_b.contract_address).call()
    ).result.data
    assert reserve_data.current_lending_rate == 2300625 * 10**17
    assert reserve_data.current_borrowing_rate == 51125 * 10**21


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
            Call(
                setup.market.contract_address,
                get_selector_from_name("enable_collateral"),
                [
                    setup.token_b.contract_address,  # token
                ],
            ),
        ]
    )

    # Borrowing rate:
    #   Utilization rate = 22.5 / 15,000 = 0.0015
    #   Borrowing rate = 0.05 + 0.2 * 0.0015 / 0.8 = 0.050375 => 50375 * 10 ** 21
    # Lending rate:
    #   Lending rate = 0.050375 * 0.0015 = 0.0000755625 => 755625 * 10 ** 17
    reserve_data = (
        await setup.market.get_reserve_data(setup.token_b.contract_address).call()
    ).result.data
    assert reserve_data.current_lending_rate == 755625 * 10**17
    assert reserve_data.current_borrowing_rate == 50375 * 10**21


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
    #   Borrowing rate = 0.05 + 0.2 * 0.0045 / 0.8 = 0.051125 => 51125 * 10 ** 21
    # Lending rate:
    #   Lending rate = 0.051125 * 0.0045 = 0.0002300625 => 2300625 * 10 ** 17
    reserve_data = (
        await setup.market.get_reserve_data(setup.token_b.contract_address).call()
    ).result.data
    assert reserve_data.current_lending_rate == 2300625 * 10**17
    assert reserve_data.current_borrowing_rate == 51125 * 10**21


@pytest.mark.asyncio
# TODO: test treasury balance
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
    #   Interest = 0.000113765625 * 10000 * 100 * (1 - 20%) / (365 * 86400) = 0.000002885987442922374429223
    #                                                         => 2885987442922
    #   Total balance = 10000 * 10 ** 18 + 2885987442922
    assert (
        await setup_with_loan.z_token_b.balanceOf(setup_with_loan.bob.address).call()
    ).result.balance == (Uint256.from_int(10000 * 10**18 + 2885987442922))


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
    #   Interest = 0.0505625 * 22.5 * 100 / (365 * 86400) = 0.000003607484303652968036529
    #                                                   => 3607484303652
    #   Total debt = 22.5 * 10 ** 18 + 3607484303652
    assert (
        await setup_with_loan.market.get_user_debt_for_token(
            setup_with_loan.alice.address, setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (225 * 10**17 + 3607484303652)
    assert (
        await setup_with_loan.market.get_total_debt_for_token(
            setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (225 * 10**17 + 3607484303652)


@pytest.mark.asyncio
async def test_repay_all_with_interest(setup_with_loan: Setup):
    setup_with_loan.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup_with_loan.starknet.state.state.block_info.block_number,
        100,
    )

    # Same as `test_debt_accumulation`
    # Total debt = 22.500003607484303652 TST_B

    await setup_with_loan.bob.execute(
        [
            Call(
                setup_with_loan.token_b.contract_address,
                get_selector_from_name("transfer"),
                [
                    setup_with_loan.alice.address,  # recipient
                    *Uint256.from_int(1 * 10**18),  # amount
                ],
            ),
        ]
    )

    await setup_with_loan.alice.execute(
        [
            Call(
                setup_with_loan.token_b.contract_address,
                get_selector_from_name("approve"),
                [
                    setup_with_loan.market.contract_address,  # spender
                    *Uint256.from_int(23 * 10**18),  # amount
                ],
            ),
            Call(
                setup_with_loan.market.contract_address,
                get_selector_from_name("repay_all"),
                [
                    setup_with_loan.token_b.contract_address,  # token
                ],
            ),
        ]
    )

    # Alice TST_B balance:
    #   22.5 + 1 - 22.500003607484303652 = 0.999996392515696348
    assert (
        await setup_with_loan.token_b.balanceOf(setup_with_loan.alice.address).call()
    ).result.balance == (Uint256.from_int(999996392515696348))

    # No more debt in system
    assert (
        await setup_with_loan.market.get_user_debt_for_token(
            setup_with_loan.alice.address, setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (0)
    assert (
        await setup_with_loan.market.get_total_debt_for_token(
            setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (0)

    # No more debt accumulation

    setup_with_loan.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup_with_loan.starknet.state.state.block_info.block_number,
        200,
    )

    assert (
        await setup_with_loan.market.get_user_debt_for_token(
            setup_with_loan.alice.address, setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (0)
    assert (
        await setup_with_loan.market.get_total_debt_for_token(
            setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (0)


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
            Call(
                setup.market.contract_address,
                get_selector_from_name("enable_collateral"),
                [
                    setup.token_a.contract_address,  # token
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
    # Total debt is 22.500003607484303652 (based on `test_debt_accumulation`)
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
    #   Expected: 21500003607484303652
    #   Actual  : 21500003607484303653
    assert (
        await setup_with_loan.market.get_user_debt_for_token(
            setup_with_loan.alice.address, setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (21500003607484303653)
    assert (
        await setup_with_loan.market.get_total_debt_for_token(
            setup_with_loan.token_b.contract_address
        ).call()
    ).result.debt == (21500003607484303653)
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
    #     Utilization rate = 21.500003607484303653 / 10,000.000003607484303653
    #                      = 0.002150000359972821110154974
    #     Borrowing rate = 0.05 + 0.2 * 0.002150000359972821110154974 / 0.8
    #                    = 0.050537500089993205277538743
    #   Lending rate:
    #     Lending rate = 0.050537500089993205277538743 * 0.002150000359972821110154974
    #                  = 0.000108655643385611870596273
    reserve_data = (
        await setup_with_loan.market.get_reserve_data(
            setup_with_loan.token_b.contract_address
        ).call()
    ).result.data
    assert reserve_data.current_lending_rate == 108655643385611870596273
    assert reserve_data.current_borrowing_rate == 50537500089993205277538743


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


@pytest.mark.asyncio
async def test_event_emission(setup: Setup):
    await setup.alice.execute(
        [
            Call(
                setup.token_a.contract_address,
                get_selector_from_name("approve"),
                [
                    setup.market.contract_address,  # spender
                    *Uint256.from_int(100 * 10**18),  # amount
                ],
            )
        ]
    )

    # Deposit emits the events
    await assert_events_emitted(
        setup.alice.execute(
            [
                Call(
                    setup.market.contract_address,
                    get_selector_from_name("deposit"),
                    [
                        setup.token_a.contract_address,  # token
                        100 * 10**18,  # amount
                    ],
                ),
            ]
        ),
        [
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("AccumulatorsSync")],
                data=[
                    setup.token_a.contract_address,  # token
                    1 * 10**27,  # lending_accumulator
                    1 * 10**27,  # debt_accumulator
                ],
            ),
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("Deposit")],
                data=[
                    setup.alice.address,  # user
                    setup.token_a.contract_address,  # token
                    100 * 10**18,  # face_amount
                ],
            ),
        ],
    )

    # 100 seconds passed
    setup.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup.starknet.state.state.block_info.block_number,
        100,
    )

    # Bob deposits 10,000 TST_B so that Alice can borrow.
    # Accumulators unchanged
    await assert_events_emitted(
        setup.bob.execute(
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
        ),
        [
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("AccumulatorsSync")],
                data=[
                    setup.token_b.contract_address,  # token
                    1 * 10**27,  # lending_accumulator
                    1 * 10**27,  # debt_accumulator
                ],
            ),
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("Deposit")],
                data=[
                    setup.bob.address,  # user
                    setup.token_b.contract_address,  # token
                    10_000 * 10**18,  # face_amount
                ],
            ),
        ],
    )

    # 100 seconds passed
    setup.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup.starknet.state.state.block_info.block_number,
        200,
    )

    # Alice borrows 22.5 TST_B
    # Accumulators unchanged
    await assert_events_emitted(
        setup.alice.execute(
            [
                Call(
                    setup.market.contract_address,
                    get_selector_from_name("enable_collateral"),
                    [
                        setup.token_a.contract_address,  # token
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
        ),
        [
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("AccumulatorsSync")],
                data=[
                    setup.token_b.contract_address,  # token
                    1 * 10**27,  # lending_accumulator
                    1 * 10**27,  # debt_accumulator
                ],
            ),
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("Borrowing")],
                data=[
                    setup.alice.address,  # user
                    setup.token_b.contract_address,  # token
                    225 * 10**17,  # raw_amount
                    225 * 10**17,  # face_amount
                ],
            ),
        ],
    )

    # 100 seconds passed
    setup.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup.starknet.state.state.block_info.block_number,
        300,
    )

    # Accumulations:
    #   Interest rate (see `test_borrow_token`):
    #     Borrowing rate = 0.0505625
    #     Lending rate = 0.000113765625
    #   Lending accmulator:
    #     1 * (1 + (100 * 0.000113765625 * (1 - 20%)) / (365 * 86400)) = 1.000000000288598744292237442
    #   Debt accmulator:
    #     1 * (1 + (100 * 0.0505625) / (365 * 86400)) = 1.000000160332635717909690512

    # Alice repays 1 TST_B
    #   Raw amount repaid:
    #     1 / 1.000000160332635717909690512 = 0.999999839667389988
    await assert_events_emitted(
        setup.alice.execute(
            [
                Call(
                    setup.token_b.contract_address,
                    get_selector_from_name("approve"),
                    [
                        setup.market.contract_address,  # spender
                        *Uint256.from_int(1 * 10**18),  # amount
                    ],
                ),
                Call(
                    setup.market.contract_address,
                    get_selector_from_name("repay"),
                    [
                        setup.token_b.contract_address,  # token
                        1 * 10**18,  # amount
                    ],
                ),
            ]
        ),
        [
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("AccumulatorsSync")],
                data=[
                    setup.token_b.contract_address,  # token
                    1000000000288598744292237442,  # lending_accumulator
                    1000000160332635717909690512,  # debt_accumulator
                ],
            ),
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("Repayment")],
                data=[
                    setup.alice.address,  # user
                    setup.token_b.contract_address,  # token
                    999999839667389988,  # raw_amount
                    1 * 10**18,  # face_amount
                ],
            ),
        ],
    )

    # 100 seconds passed
    setup.starknet.state.state.block_info = BlockInfo.create_for_testing(
        setup.starknet.state.state.block_info.block_number,
        400,
    )

    # Accumulations:
    #   Interest rate (see `test_debt_repayment`):
    #     Borrowing rate = 0.050537500089993205277538743
    #     Lending rate = 0.000108655643385611870596273
    #   Lending accmulator:
    #     1.000000000288598744292237442 * (1 + (100 * 0.000108655643385611870596273 * (1 - 20%)) / (365 * 86400))
    #     = 1.000000000564234572341374307
    #   Debt accmulator:
    #     1.000000160332635717909690512 * (1 + (100 * 0.050537500089993205277538743) / (365 * 86400))
    #     = 1.000000320586022935070387176

    # Bob withdraws 5,000 TST_B
    await assert_events_emitted(
        setup.bob.execute(
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
        ),
        [
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("AccumulatorsSync")],
                data=[
                    setup.token_b.contract_address,  # token
                    1000000000564234572341374307,  # lending_accumulator
                    1000000320586022935070387176,  # debt_accumulator
                ],
            ),
            Event(
                from_address=setup.market.contract_address,
                keys=[get_selector_from_name("Withdrawal")],
                data=[
                    setup.bob.address,  # user
                    setup.token_b.contract_address,  # token
                    5_000 * 10**18,  # face_amount
                ],
            ),
        ],
    )


# Flash loan sanity test
# TODO: add more test cases for flash loans
@pytest.mark.asyncio
async def test_flashloan(setup_with_loan: Setup):
    setup = setup_with_loan
    callback = await setup.starknet.deploy(
        source=PATH_FLASH_LOAN_HANDLER,
        constructor_calldata=[],
        cairo_path=[CAIRO_PATH],
    )

    # Sends enough token to callback contract so that it can return funds
    await setup.alice.execute(
        [
            Call(
                setup_with_loan.token_a.contract_address,
                get_selector_from_name("transfer"),
                [
                    callback.contract_address,  # recipient
                    *Uint256.from_int(1_000 * 10**18),  # amount
                ],
            ),
        ]
    )

    # Returning 1 unit less than required
    await assert_reverted_with(
        setup.alice.execute(
            [
                Call(
                    callback.contract_address,
                    get_selector_from_name("take_flash_loan"),
                    [
                        setup.market.contract_address,  # market_addr
                        setup.token_a.contract_address,  # token
                        100 * 10**18,  # amount
                        105 * 10**18 - 1,  # return_amount
                    ],
                ),
            ]
        ),
        "Market: insufficient amount repaid",
    )

    setup.alice.execute(
        [
            Call(
                callback.contract_address,
                get_selector_from_name("take_flash_loan"),
                [
                    setup.market.contract_address,  # market_addr
                    setup.token_a.contract_address,  # token
                    100 * 10**18,  # amount
                    105 * 10**18,  # return_amount
                ],
            ),
        ]
    ),
