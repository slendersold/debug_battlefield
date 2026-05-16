#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-target-asan}"

export RUSTFLAGS="-Zsanitizer=address -Cpanic=abort -Zpanic_abort_tests"
export RUSTDOCFLAGS="${RUSTFLAGS}"

echo "ASan: cargo +nightly test --tests (without criterion-bench)"
cargo +nightly test --tests "$@"
