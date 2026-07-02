#!/usr/bin/env bash
set -euo pipefail

MAX_ROUNDS="${1:-10}"

for i in $(seq 1 "$MAX_ROUNDS"); do
  echo "=== Selfcheck round $i/$MAX_ROUNDS ==="

  if scripts/selfcheck.sh; then
    echo "PASS"
    exit 0
  fi

  echo "FAIL: inspect reports/selfcheck_report.md and repair"
  exit 1
done

echo "FAILED after $MAX_ROUNDS rounds"
exit 1
