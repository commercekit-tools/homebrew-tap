# Contributing

Changes to this tap are made through focused pull requests. Do not push
directly to `main`, commit downloaded binaries or archives, or include private
source links, credentials, customer data, or local machine paths.

## Formula updates

Published CommerceKit CLI release assets are immutable. Never replace an asset,
move a tag, or reuse a published version. Update a formula only after the new
public release is complete:

1. Verify the new public CommerceKit CLI release and prerelease/stable status.
2. Record its exact version and tag.
3. Download and validate `release-manifest.json`.
4. Download and validate `SHA256SUMS`.
5. Update all four macOS/Linux archive URLs and SHA-256 values together.
6. Update and run the release-contract verifier and its offline tests.
7. Run Homebrew style and the external-tap audit.
8. Test installation on each natively available platform and structurally
   verify the remaining targets.
9. Open a pull request with the release and test evidence.
10. Merge only after the required checks pass and the change is approved.

Do not add Windows assets to the formula. The supported Homebrew matrix is
macOS ARM64, macOS Intel/x64, Linux ARM64, and Linux x64.

## Verification

Run the dependency-free verifier tests and live public-release check:

```bash
ruby test/verify_release_contract_test.rb
ruby scripts/verify-release-contract.rb
```

Register a committed local checkout as the tap before running formula-name
commands:

```bash
brew tap commercekit-tools/tap "$(pwd)" --custom-remote
```

Then run:

```bash
brew style commercekit-tools/tap/commercekit
brew audit --strict --online --os=all --arch=all commercekit-tools/tap/commercekit
brew install --build-from-source commercekit-tools/tap/commercekit
brew test commercekit-tools/tap/commercekit
commercekit --version
commercekit cron explain "0 0 2 * * ?"
brew linkage --test commercekit-tools/tap/commercekit
brew uninstall commercekit
```

The formula must remain dependency-free. Do not add Node.js, Bun, pnpm, a
compiler, or another build dependency for the standalone executable.

Homebrew's built-in SHA-256 enforcement protects installation, while the
independent release-contract verifier checks the same values against the
public manifest and checksum file. CI does not mutate the real formula to run
a separate negative-checksum installation.

Native execution can verify only the current host architecture. Report which
targets were run natively and which received release-contract verification.
Do not claim a cross-version upgrade test until a second public CLI version
exists.

Formula updates remain manual for the initial preview. Do not add a `livecheck`
block or an automatic formula-bump workflow until the prerelease selection and
update policy are deliberately designed and tested.

## Pull requests

Keep formula changes, release-contract updates, CI changes, and documentation
reviewable. Complete the pull request checklist and include the commands that
actually ran. Formula updates must change the version, URLs, hashes, verifier
contract, tests, and documentation consistently.

Security reports must follow [SECURITY.md](SECURITY.md) and must not be posted
in a public issue or pull request.
