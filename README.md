# Paper

A small, free, open-source paper-texture overlay for Apple Silicon Macs running macOS 13 or later.

Paper includes all 26 textures in the pinned Deckle catalog, favorites, saved looks, intensity and grain controls, an instant comparison, snooze, display selection, app exclusions, fixed-time or solar schedules, native Shortcuts actions, battery/Low Power Mode pause, and Deckle-compatible JSON imports. The menu-bar shortcut is **Shift–Option–Command–P**. Launch at login is optional.

**Soft Wove** is the default for new installations and appears first in the picker. All quiet-reading, material, tinted, dark and Spectral+ papers are available. Existing selections are preserved when updating; missing or removed imported selections fall back to Soft Wove. The catalog comes directly from the pinned Deckle source, without a separate list of selected IDs.

Open Paper to show settings. Close the settings window to leave the effect running. Use its menu-bar icon to toggle, snooze or quit. Comparison ends when settings close. Snoozing, excluded apps/displays, battery rules and schedules never override the master off switch.

Both snooze menus offer 15/30/60/120 minutes, **Until tomorrow at 6 AM**, and **Custom duration…** (1–1,440 whole minutes). Tomorrow means the next calendar day in the Mac's current time zone; the deadline is saved as an absolute time. A snooze survives relaunch, and its expiry still respects schedule, battery and exclusion rules.

The fixed-time schedule uses the Mac's local time, supports overnight windows, includes the start time and excludes the end time. Equal start/end times mean all day. Nonexistent daylight-saving times advance to the next valid time; repeated times use the first occurrence. A one-shot timer and wake/timezone notifications update the effect without polling.

Favorite papers appear first in the texture picker. **Saved looks** keeps up to eight named combinations of texture, intensity and grain. Saving an existing name replaces that look while preserving its Shortcuts identity. Applying a look never enables Paper or changes snooze, schedules, power rules or exclusions. Removing a custom paper also removes its favorites and saved looks.

Solar schedules offer **Sunset to sunrise** and **Sunrise to sunset**. Choose a city; lookup uses Apple's geocoding service without device-location permission. Approximate times are calculated locally with NOAA's solar equations in the city's time zone. The city stays fixed when you travel. Missing/invalid cities pause the overlay; polar day/night is handled explicitly and rechecked daily. Clear a city from the city sheet.

Shortcuts exposes **Toggle Paper**, **Set Paper Enabled**, **Snooze Paper**, **Select Paper Texture**, and **Apply Paper Look**. These open Paper and call the same state commands as its controls. Texture and look parameters use stable identities; removed selections fail with a readable error. On newer macOS, running App Intents requires a validated signing identity; use the signed build rather than an ad-hoc build.

Use **Import paper…** to choose one or more Deckle JSON recipes, including `.decklepaper.json` files. Each recipe receives a fresh local identity while preserving its rendering seed. Imports are limited to 1 MB per file and 50 saved papers. Invalid files report an error while valid files still import. Remove an imported paper with its button below the picker. There is no editor or online gallery in this version.

The overlay never captures your screen or changes display gamma. It does not require Accessibility, Input Monitoring or Screen Recording permission. Settings and recipes remain local in the `xyz.dustwave.paper` preferences domain. City lookup sends only the city you enter to Apple's service. Pause the effect for screenshots, screen sharing and color-sensitive work; it does not promise to hide itself from capture tools.

To build the source ZIP, use Xcode 27 or later (for SwiftPM App Intents metadata extraction). The app's deployment target remains macOS 13:

```sh
swift test
./script/build_and_run.sh --verify
```

In a Git checkout, also initialize and validate the Platform pin with Node 20.9+:

```sh
git submodule update --init
node script/validate.mjs
```

The new Platform fixture commit is local and unpublished. This delivery includes a Git bundle and migration instructions for importing it; the source ZIP already includes the complete pinned tree.

The Codex Run action calls that same script. `--build-only` stages `dist/Paper.app`; `--logs` streams logs after launch. The script creates an arm64 release binary and an ad-hoc development signature unless `PAPER_SIGNING_IDENTITY` names an installed Developer ID identity. App Intents metadata is extracted into the bundle before signing. There is no automatic updater.

From a committed Git checkout, `./script/package.sh` builds the local DMG and source ZIP in `outputs/`. The source ZIP includes the pinned Platform source tree; pin validation itself needs Git metadata. An example import is in `docs/examples/soft-linen.decklepaper.json`.

`./script/package.sh --notarize` uses the installed Developer ID identity, reads the API key and issuer from iCloud Drive's **Apple Auth**, signs/notarizes/staples the app and DMG, and verifies Gatekeeper acceptance. Set `DUSTWAVE_APPLE_AUTH_DIR` to override the credential directory or `PAPER_SIGNING_IDENTITY` if more than one identity is installed. Credentials remain outside the repository and artifacts. Notarization receipts retain submission IDs for retry; no public upload or release is performed.

The [native display suite](Tests/native_display/README.md) uses Platform's shared test-only virtual-monitor fixture, with Paper-specific geometry, focus, exclusion and hot-plug checks. Helpers are never bundled with the app. This does not qualify physical HDR/cable/wake behavior or every supported OS.

The renderer and recipe model are pinned, attributed Deckle sources. Record supplies the login adapter, shortcut-registration pattern and display-placement lessons. The Platform gitlink supplies the existing pin/documentation/integrity tools without importing its unrelated speech or AI runtime. See [upstream review](docs/upstream-review.md), [third-party notices](THIRD_PARTY_NOTICES.md), and [testing evidence](docs/testing.md).

The application is MIT-licensed. The separate native display test tooling is GPL-3.0, retaining OwlSwitch's license. This is an independent app, not a Paperman or Deckle release.
