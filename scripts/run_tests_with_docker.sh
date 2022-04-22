#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname "$0" )" &> /dev/null && pwd )
REPO_ROOT=$( cd -- "$( dirname $( dirname "$0" ) )" &> /dev/null && pwd )

docker run --rm \
    -v "${SCRIPT_DIR}/entrypoints/run_tests.sh:/entry.sh:ro" \
    -v "${REPO_ROOT}/:/src/" \
    --entrypoint "/entry.sh" \
    shardlabs/cairo-cli:0.8.1
