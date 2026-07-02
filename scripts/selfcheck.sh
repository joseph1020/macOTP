#!/usr/bin/env bash
set -euo pipefail

mkdir -p reports

REPORT="reports/selfcheck_report.md"
: > "$REPORT"

echo "# Selfcheck Report" >> "$REPORT"
echo "" >> "$REPORT"

echo "## Swift Build" >> "$REPORT"
swift build -c release >> "$REPORT" 2>&1

echo "" >> "$REPORT"
echo "## Swift Test" >> "$REPORT"
swift test >> "$REPORT" 2>&1

echo "" >> "$REPORT"
echo "## macOTP Selftest" >> "$REPORT"
swift run macotp-selftest >> "$REPORT" 2>&1

echo "" >> "$REPORT"
echo "## Forbidden Pattern Scan" >> "$REPORT"

FAIL=0

check_forbidden() {
  local pattern="$1"
  local label="$2"

  if grep -R "$pattern" Sources Tests scripts --exclude="selfcheck.sh" >/tmp/macotp_scan.txt 2>/dev/null; then
    echo "FAIL: Found forbidden pattern: $label" >> "$REPORT"
    cat /tmp/macotp_scan.txt >> "$REPORT"
    FAIL=1
  else
    echo "PASS: $label not found" >> "$REPORT"
  fi
}

check_forbidden "strings " "strings command"
check_forbidden "grep " "grep command in extraction path"
check_forbidden "/tmp/msg" "temporary message body files"
check_forbidden "URLSession" "network access"
check_forbidden "print(.*body" "possible body logging"

if [ "$FAIL" -ne 0 ]; then
  echo "" >> "$REPORT"
  echo "SELF CHECK FAILED" >> "$REPORT"
  exit 1
fi

echo "" >> "$REPORT"
echo "SELF CHECK PASSED" >> "$REPORT"
