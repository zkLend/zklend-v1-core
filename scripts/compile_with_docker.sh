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
    starknet/cairo:2.6.3 \
    -c "cd /work && ./scripts/compile.sh"
