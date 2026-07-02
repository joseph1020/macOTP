# macOTP

[![CI](https://github.com/joseph1020/macOTP/actions/workflows/ci.yml/badge.svg)](https://github.com/joseph1020/macOTP/actions/workflows/ci.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-15%2B-blue.svg)](https://developer.apple.com/macos/)

macOTP is a local macOS command-line tool for finding recent one-time passwords
in Apple Messages. It reads the local Messages database in read-only mode,
extracts likely OTP codes from message text or Apple Messages attributed body
metadata, and prints or copies the matching code.

## Privacy and security model

- Local-only processing: all scanning and extraction run on the Mac where the
  command is executed.
- No telemetry: macOTP does not collect analytics, usage events, crash reports,
  or diagnostics.
- No network communication: macOTP does not make HTTP requests, open sockets, or
  call remote services.
- No OTP storage: extracted OTP values are not written to disk by macOTP.
- Read-only Messages access: the Messages database is opened read-only.
- Sanitized debug output: debug lines are intended to report metadata and
  lengths without printing OTP message bodies.

## Requirements

- macOS 15 or later.
- Swift 6.0 or later to build from source.
- Full Disk Access for the terminal application used to run macOTP.

Apple protects `~/Library/Messages/chat.db` with macOS privacy controls. If the
terminal app does not have Full Disk Access, macOTP cannot open the Messages
database and exits with a permission error. Grant access in System Settings,
then run the command again.

## Build

```sh
swift build
```

## Usage

```sh
swift run macotp [--hours N] [--days N] [--limit N] [--copy] [--json] [--debug]
```

Defaults:

- The scan window is the last 24 hours.
- The output limit is 200 OTP results.
- `--limit` accepts values up to 1000.

Examples:

```sh
swift run macotp
swift run macotp --hours 6 --copy
swift run macotp --days 3 --json
```

## Legacy attributedBody decoder

Apple Messages stores some message content in an `attributedBody` column rather
than plain text. macOTP includes a decoder for that local binary field so OTPs
can still be found when the visible message text is absent or incomplete.

The decoder handles two archive styles used by Messages:

- Modern keyed archives, decoded with `NSKeyedUnarchiver` and an explicit
  allowlist of Foundation classes.
- Legacy typed stream archives, detected by their typed stream signature and
  decoded with `NSUnarchiver`.

After decoding, macOTP extracts the attributed string plain text and selected
OTP metadata keys such as `__kIMOneTimeCodeAttributeName`, `displayCode`,
`code`, and `AuthCode`. The decoder is a compatibility layer for locally stored
Messages data; it does not change Messages, send data elsewhere, or persist OTP
values.

## Validation

```sh
swift build
swift run macotp-selftest
scripts/selfcheck.sh
git diff --check
```

## License

macOTP is released under the MIT License. See [LICENSE](LICENSE).
