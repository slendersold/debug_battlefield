#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-target}"

cargo build --tests -q
BIN=$(ls target/debug/deps/integration-* | grep -v '\.d$' | head -1)

echo "Running Valgrind on: $BIN"
valgrind --leak-check=full \
  --show-leak-kinds=definite,indirect \
  --error-exitcode=1 \
  "$BIN" "$@"
