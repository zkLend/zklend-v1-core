import pytest

from utils.account import Call, deploy_account
from utils.contracts import PATH_ERC20, PATH_MARKET
from utils.helpers import string_to_felt

from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException


@pytest.mark.asyncio
async def test_token_transferred_on_deposit():
    starknet = await Starknet.empty()

    alice = await deploy_account(starknet)

    market = await starknet.deploy(source=PATH_MARKET)
    token = await starknet.deploy(
        source=PATH_ERC20,
        constructor_calldata=[
            string_to_felt("Test Token"),  # name
            string_to_felt("TST"),  # symbol
            18,  # decimals
            10 ** (6 + 18),  # initial_supply_low
            0,  # initial_supply_high
            alice.address,  # recipient
        ],
    )

    await alice.execute(
        [
            Call(
                token.contract_address,
                get_selector_from_name("approve"),
                [
                    market.contract_address,  # spender
                    10**18,  # amount_low
                    0,  # amount_high
                ],
            )
        ]
    )
    await alice.execute(
        [
            Call(
                market.contract_address,
                get_selector_from_name("deposit"),
                [
                    token.contract_address,  # token : felt
                    10**18,  # amount_low
                    0,  # amount_high
                ],
            )
        ]
    )

    assert (await token.balanceOf(alice.address).call()).result.balance == (
        (999_999 * 10**18, 0)
    )
    assert (await token.balanceOf(market.contract_address).call()).result.balance == (
        (10**18, 0)
    )


@pytest.mark.asyncio
async def test_deposit_transfer_failed():
    starknet = await Starknet.empty()

    alice = await deploy_account(starknet)

    market = await starknet.deploy(source=PATH_MARKET)
    token = await starknet.deploy(
        source=PATH_ERC20,
        constructor_calldata=[
            string_to_felt("Test Token"),  # name
            string_to_felt("TST"),  # symbol
            18,  # decimals
            10 ** (6 + 18),  # initial_supply_low
            0,  # initial_supply_high
            alice.address,  # recipient
        ],
    )

    # transferFrom fails due to insufficient allowance
    # TODO: wrap error assertion into helper
    try:
        await alice.execute(
            [
                Call(
                    market.contract_address,
                    get_selector_from_name("deposit"),
                    [
                        token.contract_address,  # token : felt
                        10**18,  # amount_low
                        0,  # amount_high
                    ],
                )
            ]
        )
        assert False
    except StarkException as err:
        assert (
            f"\nError message: ERC20: transfer amount exceeds allowance\n"
            in err.message
        )
