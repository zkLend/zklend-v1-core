#!/bin/sh

set -e

SCRIPT_DIR=$( cd -- "$( dirname "$0" )" &> /dev/null && pwd )
REPO_ROOT=$( cd -- "$( dirname $( dirname "$0" ) )" &> /dev/null && pwd )

# Deterministically generate contract artifacts
docker run --rm \
    -v "$REPO_ROOT:/work" \
    --env "USER_ID=$(id -u)" \
    --env "GROUP_ID=$(id -g)" \
    --entrypoint sh \
    shardlabs/cairo-cli:0.9.1 \
    -c "cd /work && ./scripts/compile.sh"

# Using prettier instead of `jq` due to known issue:
#   https://github.com/xJonathanLEI/starknet-rs/issues/76#issuecomment-1058153538
docker run --rm \
    -v "$REPO_ROOT/build:/work" \
    --user root \
    tmknom/prettier:2.6.2 \
    --write .
