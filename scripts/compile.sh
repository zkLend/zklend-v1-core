#!/bin/sh

set -e

SCRIPT_DIR=$( cd -- "$( dirname "$0" )" &> /dev/null && pwd )
REPO_ROOT=$( cd -- "$( dirname $( dirname "$0" ) )" &> /dev/null && pwd )

compile () {
  MODULE="$1"
  NAME="$2"
  OUTPUT="$REPO_ROOT/build/$NAME.json"

  echo "Compiling $MODULE::$NAME"

  # This is better than using the output option, which does not emit EOL at the end.
  starknet-compile -c "$MODULE::$NAME" $REPO_ROOT > $OUTPUT

  if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
    chown $USER_ID:$GROUP_ID $OUTPUT
  fi
}

mkdir -p "$REPO_ROOT/build"

compile zklend::market Market
compile zklend::z_token ZToken
compile zklend::default_price_oracle DefaultPriceOracle
compile zklend::irms::default_interest_rate_model DefaultInterestRateModel
compile zklend::oracles::pragma_oracle_adapter PragmaOracleAdapter

if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
  chown -R $USER_ID:$GROUP_ID "$REPO_ROOT/build"
fi
