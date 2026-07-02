# Contributing

Thank you for improving macOTP. This repository is public, so contributions
must avoid exposing real OTPs, message contents, phone numbers, database files,
or other private data.

## Development rules

- Do not add telemetry, analytics, crash reporting, or usage tracking.
- Do not add network communication.
- Do not store OTP values on disk.
- Keep Messages database access read-only.
- Preserve local-only processing.
- Avoid logging raw message bodies or OTP values.
- Keep changes small and focused.

## Full Disk Access

macOTP reads `~/Library/Messages/chat.db`, which is protected by macOS privacy
controls. Manual testing against the real Messages database requires Full Disk
Access for the terminal application running macOTP. Unit tests and selftests
should use synthetic data and must not require contributors to share private
Messages data.

## Legacy attributedBody decoder

The attributed body decoder exists for compatibility with Apple Messages rows
that store content in the `attributedBody` column. It supports both modern keyed
archives and legacy typed stream archives, extracts plain text and selected OTP
metadata, and must remain local-only. Changes to this area should include tests
with synthetic fixtures and should not introduce persistence or network access.

## Validation

Run these checks before submitting a change:

```sh
swift build
swift run macotp-selftest
scripts/selfcheck.sh
git diff --check
```

For extraction changes, also run:

```sh
swift test
```

## Pull requests

Describe the behavior change, list validation performed, and call out any
remaining risks. If a change touches privacy, security, extraction behavior, or
Messages database access, explain why the local-only, no-telemetry, no-network,
and no-OTP-storage guarantees still hold.
