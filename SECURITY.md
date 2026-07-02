# Security Policy

## Supported versions

This public repository currently supports the active source version on macOS 15
or later.

## Reporting a vulnerability

Please report suspected vulnerabilities through the repository's private
security reporting channel if available. If private reporting is not available,
open an issue with a minimal description and avoid posting OTPs, message
contents, personal phone numbers, or other sensitive data.

Useful reports include:

- macOTP version or commit.
- macOS version.
- Exact command-line flags used.
- Sanitized error output.
- A minimal reproduction that does not include real OTPs or private message
  content.

## Privacy guarantees

macOTP is designed around local-only processing:

- No telemetry is collected.
- No network communication is performed.
- No OTP values are stored by macOTP.
- The Apple Messages database is opened read-only.

The tool requires Full Disk Access because macOS protects the local Messages
database at `~/Library/Messages/chat.db`. Grant Full Disk Access only to the
terminal application you trust and use to run macOTP.

## Sensitive data handling

Do not include real OTPs, message bodies, phone numbers, account identifiers, or
database files in public issues or pull requests. Use synthetic examples such as
`123456` when demonstrating behavior.
