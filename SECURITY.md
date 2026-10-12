# Security Policy

## Supported versions

Security fixes are provided for the most recent CommerceKit CLI formula unless
its release notes state otherwise. The current formula is a developer preview.

## Reporting a vulnerability

Do not report a suspected vulnerability in a public issue, pull request, or
discussion. Email `commercekit.tools@gmail.com` with the subject
`CommerceKit Homebrew security report` and include:

- the formula and CLI version;
- the operating system and architecture;
- whether the downloaded archive matched the formula checksum;
- a concise description of the issue and its impact;
- reproducible steps or a minimal proof of concept; and
- a safe contact method for follow-up.

Remove customer data, credentials, private project files, and other sensitive
values from reports. Reports are reviewed privately before coordinated public
disclosure.

## Security scope

This repository covers formula selection, release URLs and checksums,
installation behavior, verification tooling, and tap workflows. Security
issues in the CommerceKit executable itself follow the
[CLI release security process](https://github.com/commercekit-tools/cli/security/policy).

This public tap does not create a disclosure channel into the private source
repository. For non-security tap defects, use the
[tap issue tracker](https://github.com/commercekit-tools/homebrew-tap/issues).
