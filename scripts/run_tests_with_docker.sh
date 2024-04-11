#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname "$0" )" &> /dev/null && pwd )
REPO_ROOT=$( cd -- "$( dirname $( dirname "$0" ) )" &> /dev/null && pwd )

docker run --rm \
    -v "${REPO_ROOT}:/work" \
    --entrypoint "cairo-test" \
    starknet/cairo:2.6.3 \
    --starknet /work
