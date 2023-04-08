#!/bin/sh

set -e

SCRIPT_DIR=$( cd -- "$( dirname "$0" )" &> /dev/null && pwd )
REPO_ROOT=$( cd -- "$( dirname $( dirname "$0" ) )" &> /dev/null && pwd )

compile () {
  SOURCE="$1"
  SOURCE_DIR="$(dirname "$SOURCE")"
  SOURCE_FILE="$(basename -- "$SOURCE")"
  OUTPUT_DIR="../build/$SOURCE_DIR"
  OUTPUT="$OUTPUT_DIR/${SOURCE_FILE%.*}.json"

  echo "Compiling $(realpath $SOURCE)"

  mkdir -p "$OUTPUT_DIR"

  # Ignores debug info for smaller artifacts
  starknet-compile-deprecated --no_debug_info $SOURCE > $OUTPUT

  if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
    chown $USER_ID:$GROUP_ID $OUTPUT_DIR
    chown $USER_ID:$GROUP_ID $OUTPUT
  fi
}

cd "$REPO_ROOT/src"
mkdir -p "$REPO_ROOT/build/zklend"

find -type f -name '*.cairo' | while read SOURCE; do
  compile "$SOURCE"
done

if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
  chown -R $USER_ID:$GROUP_ID "$REPO_ROOT/build"
fi
