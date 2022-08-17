from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent
SRC_ROOT = REPO_ROOT / "src"
CONTRACT_ROOT = SRC_ROOT / "zklend"
TESTS_ROOT = REPO_ROOT / "tests"

CAIRO_PATH = str(SRC_ROOT)

PATH_MARKET = str(CONTRACT_ROOT / "Market.cairo")
PATH_ZTOKEN = str(CONTRACT_ROOT / "ZToken.cairo")
PATH_PROXY = str(CONTRACT_ROOT / "Proxy.cairo")
PATH_DEFAULT_INTEREST_RATE_MODEL = str(
    CONTRACT_ROOT / "irms" / "DefaultInterestRateModel.cairo"
)
PATH_ERC20 = str(
    SRC_ROOT / "openzeppelin" / "token" / "erc20" / "presets" / "ERC20.cairo"
)
PATH_ERC20_MINTABLE = str(
    SRC_ROOT / "openzeppelin" / "token" / "erc20" / "presets" / "ERC20Mintable.cairo"
)

PATH_MOCK_SAFE_CAST = str(TESTS_ROOT / "mocks" / "SafeCast_mock.cairo")
PATH_MOCK_SAFE_MATH = str(TESTS_ROOT / "mocks" / "SafeMath_mock.cairo")
PATH_MOCK_SAFE_DECIMAL_MATH = str(TESTS_ROOT / "mocks" / "SafeDecimalMath_mock.cairo")
PATH_MOCK_MATH = str(TESTS_ROOT / "mocks" / "Math_mock.cairo")
PATH_MOCK_PRICE_ORACLE = str(TESTS_ROOT / "mocks" / "MockPriceOracle.cairo")
PATH_MOCK_MARKET = str(TESTS_ROOT / "mocks" / "MockMarket.cairo")
PATH_FLASH_LOAN_HANDLER = str(TESTS_ROOT / "mocks" / "FlashLoanHandler.cairo")
