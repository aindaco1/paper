# Release workflow

A release is a separate task. Require a clean, committed source tree, a published exact Platform pin, passing CI/source/Swift gates, real-app acceptance, and reviewed notes. Never replace an already published version's archive or key.

1. Bump both versions in `Configuration/Info.plist`, update `CHANGELOG.md`, and write `docs/releases/VERSION.md`.
2. Run the contributor checks. Sign and package with `./script/package.sh --notarize`; the existing Apple Auth adapter reads credentials in place. Verify the app and DMG signatures, notarization/staples, Gatekeeper, bundle metadata, and a fresh source-ZIP build.
3. Generate `outputs/appcast.xml` with `python3 script/generate_appcast.py`. Paper's Sparkle Ed25519 private key stays in Keychain account `xyz.dustwave.paper`; only its public key is tracked. Secure key backup is operator-owned. Do not export a private key into the repository, logs, CI artifacts or public assets.
4. Publish a new GitHub tag/release in `aindaco1/paper` with its DMG, complete source ZIP, update ZIP, checksums and appcast. The official feed is the latest release's `appcast.xml`. Verify downloaded public assets against local hashes and signatures.
5. Exercise a safe older-version installation through Sparkle check, download, Install and Relaunch. Verify the final version and executable; preserve the user's app/preferences. A first updater release uses a local signed older-version fixture because 0.3.0 and earlier contain no updater. Never publish that fixture.

CI only builds/validates; it has no signing keys or release write permission. The updater installs only after user action. Local build, notarization, public feed and installed update acceptance are distinct outcomes.

## Reporting relay

Synchronize the app-owned `integrations/crash-relay` files using `node script/sync-crash-relay.mjs /path/to/crash-relay`. Keep the existing shared `ReviewedReportGroup`, product routes, bindings and permissions. Run all relay tests and dry-run deployment; deploy through its existing workflow. Add only Paper to the GitHub App's selected repositories if needed. Validate synthetic create/duplicate/aggregate/reopen delivery and close the synthetic issues. Existing namespaces must never be deleted for rollback; disable `PAPER_REPORTS_ENABLED` instead.
