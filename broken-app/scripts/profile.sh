#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-target}"
mkdir -p artifacts

if [[ "$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo 4)" -gt 1 ]]; then
  echo "Hint: sudo sysctl -w kernel.perf_event_paranoid=-1"
fi

cargo build --release -q
PERF_DATA=artifacts/perf.data
perf record -g --call-graph dwarf -o "$PERF_DATA" target/release/demo 2>&1 | tee artifacts/perf_summary.txt

if command -v stackcollapse-perf.pl >/dev/null && command -v flamegraph.pl >/dev/null; then
  perf script -i "$PERF_DATA" | stackcollapse-perf.pl | flamegraph.pl > artifacts/flamegraph.svg
  echo "Wrote artifacts/flamegraph.svg"
  rm -f "$PERF_DATA"
else
  perf report -i "$PERF_DATA" --stdio | head -80 >> artifacts/perf_summary.txt
  rm -f "$PERF_DATA"
fi
