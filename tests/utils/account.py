from pathlib import Path
from typing import List, Optional, Tuple

from utils.contracts import CAIRO_PATH
from utils.helpers import string_to_felt

from starkware.cairo.common.hash_state import compute_hash_on_elements
from starkware.crypto.signature.signature import private_to_stark_key, sign
from starkware.starknet.services.api.gateway.transaction import InvokeFunction
from starkware.starknet.testing.contract import (
    StarknetContract,
)
from starkware.starknet.testing.starknet import Starknet, TransactionExecutionInfo
from starkware.starknet.testing.state import InternalTransaction

PREFIX_TRANSACTION = string_to_felt("StarkNet Transaction")

ACCOUNT_CONTRACT_FILE = str(
    Path(__file__).parent.parent.parent
    / "src"
    / "openzeppelin"
    / "account"
    / "presets"
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

    async def execute(self, calls: List[Call]) -> TransactionExecutionInfo:
        nonce = await self.__account_contract.state.state.get_nonce_at(
            self.__account_contract.contract_address
        )

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

        transaction_hash = compute_hash_on_elements(
            [
                string_to_felt("invoke"),
                1,  # version
                self.address,
                0,
                compute_hash_on_elements(execute_calldata),
                0,  # max_fee
                string_to_felt("SN_GOERLI"),
                nonce,
            ]
        )
        sig_r, sig_s = sign(transaction_hash, self.__private_key)

        result = await self.__account_contract.state.execute_tx(
            InternalTransaction.from_external(
                external_tx=InvokeFunction(
                    sender_address=self.address,
                    calldata=execute_calldata,
                    entry_point_selector=None,
                    signature=[sig_r, sig_s],
                    max_fee=0,
                    version=1,
                    nonce=nonce,
                ),
                general_config=self.__account_contract.state.general_config,
            )
        )

        return result

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
