from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent
SRC_ROOT = REPO_ROOT / "src"
CONTRACT_ROOT = SRC_ROOT / "zklend"
TESTS_ROOT = REPO_ROOT / "tests"

CAIRO_PATH = str(SRC_ROOT)

PATH_MARKET = str(CONTRACT_ROOT / "Market.cairo")
PATH_ZTOKEN = str(CONTRACT_ROOT / "ZToken.cairo")
PATH_ZIG_ZAG_ORACLE_ADAPTER = str(
    CONTRACT_ROOT / "oracles" / "ZigZagOracleAdapter.cairo"
)
PATH_ERC20 = str(SRC_ROOT / "openzeppelin" / "token" / "erc20" / "ERC20.cairo")
PATH_ERC20_MINTABLE = str(
    SRC_ROOT / "openzeppelin" / "token" / "erc20" / "ERC20_Mintable.cairo"
)

PATH_MOCK_SAFE_CAST = str(TESTS_ROOT / "mocks" / "SafeCast_mock.cairo")
PATH_MOCK_SAFE_MATH = str(TESTS_ROOT / "mocks" / "SafeMath_mock.cairo")
PATH_MOCK_SAFE_DECIMAL_MATH = str(TESTS_ROOT / "mocks" / "SafeDecimalMath_mock.cairo")
PATH_MOCK_ZIG_ZAG_ORACLE = str(TESTS_ROOT / "mocks" / "MockZigZagOracle.cairo")
