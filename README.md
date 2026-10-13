# CommerceKit Homebrew Tap

## Overview

This is the official Homebrew tap for CommerceKit CLI. The formula installs
the standalone executable published through the public
[CommerceKit CLI releases](https://github.com/commercekit-tools/cli/releases).
It does not require Node.js, Bun, pnpm, a compiler, or a source checkout.

The CommerceKit source repository is maintained privately. This tap contains
only the formula, verification tooling, workflows, tests, and documentation
needed to distribute the published CLI archives.

## Status

The current formula installs CommerceKit CLI `0.1.0-preview.2`. This is a
developer preview and is not a stable release.

## Installation

Install the formula with its fully qualified tap name:

```bash
brew install commercekit-tools/tap/commercekit
```

Homebrew adds the tap automatically. After the tap has been added, the short
formula name `commercekit` can be used with other Homebrew commands.

## Verify installation

```bash
commercekit --version
commercekit --help
commercekit check
```

The version command should report `0.1.0-preview.2`. Run `commercekit check`
inside a project that you want CommerceKit to inspect.

## Usage

CommerceKit CLI includes developer tools for Cron expressions, ImpEx,
properties files, manifests, FlexibleSearch, Beans XML, and project-wide
checks. Discover commands and options through the built-in help:

```bash
commercekit --help
commercekit cron explain "0 0 2 * * ?"
```

Product information is available at <https://commercekit.tools>.

## Supported platforms

- macOS ARM64
- macOS Intel/x64
- Linux ARM64
- Linux x64

Windows binaries are distributed separately through the
[CommerceKit CLI releases](https://github.com/commercekit-tools/cli/releases).
Windows is not installed through this Homebrew tap.

## Upgrade

Normal future formula updates will use:

```bash
brew update
brew upgrade commercekit
```

The `0.1.0-preview.1` to `0.1.0-preview.2` update was verified with this normal
Homebrew upgrade path.

## Uninstall

Remove the formula with:

```bash
brew uninstall commercekit
```

This does not delete user-created project files or CommerceKit diagnostic
logs. To remove the tap separately after uninstalling the formula:

```bash
brew untap commercekit-tools/tap
```

## Reinstall and troubleshooting

Reinstall the current version without changing versions:

```bash
brew reinstall commercekit
```

For a formula, checksum, linking, installation, or uninstall problem, open an
issue in the [Homebrew tap repository](https://github.com/commercekit-tools/homebrew-tap/issues).
For CLI command or runtime behavior, open an issue in the
[CommerceKit CLI distribution repository](https://github.com/commercekit-tools/cli/issues).

## Release verification

The formula uses immutable, versioned GitHub Release URLs and pins each archive
to its published SHA-256 value. Homebrew performs this checksum verification
during a normal installation; users do not need to verify the archive
manually.

The `0.1.0-preview.2` release contract is available through:

- [release page](https://github.com/commercekit-tools/cli/releases/tag/cli-v0.1.0-preview.2)
- [release-manifest.json](https://github.com/commercekit-tools/cli/releases/download/cli-v0.1.0-preview.2/release-manifest.json)
- [SHA256SUMS](https://github.com/commercekit-tools/cli/releases/download/cli-v0.1.0-preview.2/SHA256SUMS)

The repository verifier checks the public release state, manifest, checksums,
all four Homebrew target mappings, archive contents, immutable URLs, and the
absence of Windows or private-source URLs in the formula:

```bash
ruby scripts/verify-release-contract.rb
```

Formula maintenance uses the external-tap audit command:

```bash
brew audit --strict --online --os=all --arch=all commercekit-tools/tap/commercekit
```

## Unsigned preview notice

The current macOS binaries are unsigned and are not Apple-notarized. The
formula does not change Gatekeeper or other macOS security settings.

## Direct-download fallback

If Homebrew is unavailable, use the named archives on the public
[CommerceKit CLI Releases page](https://github.com/commercekit-tools/cli/releases).
The release provides its own manifest, checksums, license, third-party notices,
and platform disclosures.

## Issue and support routing

- Tap or formula defect: [tap issues](https://github.com/commercekit-tools/homebrew-tap/issues)
- CLI executable or runtime defect: [CLI issues](https://github.com/commercekit-tools/cli/issues)
- Product question or general feedback: [CommerceKit contact](https://commercekit.tools/contact)
- Security concern: follow [SECURITY.md](SECURITY.md) and do not open a public issue

## Security

The formula downloads only immutable release assets and verifies their
SHA-256 values. See [SECURITY.md](SECURITY.md) for private reporting guidance
and the boundary between tap security and CLI executable security.

## Licensing

The tap repository's MIT license applies only to the formula, workflows,
scripts, tests, and documentation in this repository. CommerceKit CLI binaries
and source code are governed separately by the terms included with the CLI
release. The current CLI archive contains an MIT project license together with
`THIRD_PARTY_NOTICES` for bundled components.
