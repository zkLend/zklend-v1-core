from pathlib import Path
from typing import List, Optional, Tuple

from utils.contracts import CAIRO_PATH
from utils.helpers import string_to_felt

from starkware.cairo.common.hash_state import compute_hash_on_elements
from starkware.crypto.signature.signature import private_to_stark_key, sign
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

PREFIX_TRANSACTION = string_to_felt("StarkNet Transaction")

ACCOUNT_CONTRACT_FILE = str(
    Path(__file__).parent.parent.parent
    / "src"
    / "openzeppelin"
    / "account"
    / "Account.cairo"
)


class Call:
    to: int
    selector: int
    calldata: List[int]

    def __init__(self, to: int, selector: int, calldata: List[int]):
        self.to = to
        self.selector = selector
        self.calldata = calldata


class Account:
    """
    A wrapper type around the standard account contract interface of StarkNet.
    """

    __account_contract: StarknetContract
    __private_key: int

    def __init__(self, account_contract: StarknetContract, private_key: int):
        self.__account_contract = account_contract
        self.__private_key = private_key

    async def execute(self, calls: List[Call]):
        nonce = (await self.__account_contract.get_nonce().call()).result[0]

        raw_call_array: List[Tuple[int, int, int, int]] = []
        concated_calldata: List[int] = []
        execute_calldata: List[int] = []

        execute_calldata.append(len(calls))
        for call in calls:
            raw_call_array.append(
                (call.to, call.selector, len(concated_calldata), len(call.calldata))
            )
            execute_calldata.append(call.to)
            execute_calldata.append(call.selector)
            execute_calldata.append(len(concated_calldata))
            execute_calldata.append(len(call.calldata))
            for item in call.calldata:
                concated_calldata.append(item)
        execute_calldata.append(len(concated_calldata))
        for item in concated_calldata:
            execute_calldata.append(item)
        execute_calldata.append(nonce)

        message_hash = compute_hash_on_elements(
            [
                PREFIX_TRANSACTION,
                self.address,
                compute_hash_on_elements(
                    list(
                        map(
                            lambda item: compute_hash_on_elements(
                                [
                                    item.to,
                                    item.selector,
                                    compute_hash_on_elements(item.calldata),
                                ]
                            ),
                            calls,
                        )
                    )
                ),
                nonce,
                0,  # max_fee
                0,  # version
            ]
        )
        sig_r, sig_s = sign(message_hash, self.__private_key)

        await self.__account_contract.__execute__(
            raw_call_array, concated_calldata, nonce
        ).invoke(max_fee=0, signature=[sig_r, sig_s])

    @property
    def address(self) -> int:
        return self.__account_contract.contract_address


async def deploy_account(
    starknet: Starknet, private_key: Optional[int] = None
) -> Account:
    if private_key is None:
        private_key = 11223344556677889900

    account_contract = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE,
        constructor_calldata=[private_to_stark_key(private_key)],
        cairo_path=[CAIRO_PATH],
    )
    return Account(account_contract, private_key)
