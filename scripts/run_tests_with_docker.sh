#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname "$0" )" &> /dev/null && pwd )
REPO_ROOT=$( cd -- "$( dirname $( dirname "$0" ) )" &> /dev/null && pwd )

docker run --rm \
    -v "${SCRIPT_DIR}/entrypoints/run_tests.sh:/entry.sh:ro" \
    -v "${REPO_ROOT}:/work" \
    --entrypoint "/entry.sh" \
    starknet/cairo-lang:0.11.0.2
