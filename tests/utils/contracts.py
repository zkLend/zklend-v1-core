from pathlib import Path

SRC_ROOT = Path(__file__).parent.parent.parent / "src"
CONTRACT_ROOT = SRC_ROOT / "zklend"

PATH_MARKET = str(CONTRACT_ROOT / "Market.cairo")
PATH_ERC20 = str(SRC_ROOT / "openzeppelin" / "token" / "erc20" / "ERC20.cairo")
