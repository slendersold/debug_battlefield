#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-target-tsan}"
TARGET="$(rustc -vV | sed -n 's/^host: //p')"

export RUSTFLAGS="-Zsanitizer=thread"
export RUSTDOCFLAGS="${RUSTFLAGS}"

cargo clean -q

echo "TSan: cargo +nightly test -Zbuild-std --target $TARGET --tests"
cargo +nightly test -Zbuild-std --target "$TARGET" --tests -- --test-threads=1 "$@"
