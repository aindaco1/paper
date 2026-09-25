# Contributing to Paper

Use Xcode 27+, Node 24, and an Apple Silicon Mac. Initialize the exact Platform submodule with `git submodule update --init --recursive`. Do not edit vendored Deckle/Record files without updating their provenance and retained tests.

Quit an installed Paper copy before running a development build or the native suites. The single-instance rule otherwise reopens the existing app instead of the new binary. Normal app settings are separate from the native suites' disposable preferences.

Before a pull request:

```sh
node script/validate.mjs
node --test Tests/relay/*.test.mjs
swift test --package-path shared/dust-wave-platform/desktop
swift test
./script/build_and_run.sh --verify
```

CI runs the same source/contract/Swift checks and builds an ad-hoc app using the official GitHub `xcode-27` runner. Real pointer input, login, physical HDR, other OS versions and actual update installation are separate acceptance gates. See [testing](docs/testing.md).

Keep pure visibility/schedule policy in PaperCore and system integrations in narrow adapters. Keep the app small, reuse the shared modules, and never introduce screen capture, event taps, gamma adjustment, hidden uploads or a custom updater. Product-specific report contracts stay in Paper; relay aggregation stays shared. Keep `Package.resolved` and the Platform pin exact.

Submit clear reproduction steps and relevant checks. Use synthetic reports/media for examples. Never commit credentials, real crash logs, private paths or local outputs. Build artifacts belong in ignored `dist/`; delivery evidence belongs in ignored `outputs/`. The application is MIT; the separate display test tooling is GPL-3.0 and must not be shipped in Paper.app.
