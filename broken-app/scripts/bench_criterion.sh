#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-target}"
cargo bench --bench criterion --features criterion-bench -- "$@"
