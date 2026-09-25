# Paper

A small, free, open-source paper-texture overlay for Apple Silicon Macs running macOS 13 or later.

Paper includes all 26 textures in the pinned Deckle catalog, favorites, saved looks, intensity and grain controls, menu-bar snooze, per-display intensity, selected-app rules and exclusions, fixed-time or solar schedules, automatic day/night looks, library backup, native Shortcuts actions, battery/Low Power Mode pause, and Deckle-compatible JSON imports. The default toggle shortcut is **Shift–Option–Command–P**, editable in Settings. Launch at login is optional.

**Soft Wove** is the default for new installations and appears first in the picker. All quiet-reading, material, tinted, dark and Spectral+ papers are available. Existing selections are preserved when updating; missing or removed imported selections fall back to Soft Wove. The catalog comes directly from the pinned Deckle source, without a separate list of selected IDs.

Open Paper to show settings. Close the settings window to leave the effect running. Use its menu-bar icon for immediate actions: toggle, snooze, favorite textures, reading-strip on/off, presentation pause or quit. Settings contains configuration rather than duplicate action controls. Snoozing, excluded apps/displays, battery rules and schedules never override the master off switch.

App exclusions pause Paper when that app is active. Nonactivating floating panels, such as Atoll’s notch UI, stay above the texture while ordinary windows remain textured. Paper briefly checks public window metadata while an excluded app is running and an overlay can be visible; it does not use screenshots, window titles or Accessibility permission. Normal stacking returns when those panels close.

The menu-bar Snooze menu offers 15/30/60/120 minutes, **Until tomorrow at 6 AM**, and **Custom duration…** (1–1,440 whole minutes). Tomorrow means the next calendar day in the Mac's current time zone; the deadline is saved as an absolute time. A snooze survives relaunch, and its expiry still respects schedule, battery and exclusion rules.

The fixed-time schedule uses the Mac's local time, supports overnight windows, includes the start time and excludes the end time. Equal start/end times mean all day. Nonexistent daylight-saving times advance to the next valid time; repeated times use the first occurrence. A one-shot timer and wake/timezone notifications update the effect without polling.

Favorite papers appear first in the texture picker and in the menu’s Favorites submenu. Manual texture selection recalls its last intensity; display overrides remain independent. **Saved looks** keeps up to eight named combinations of texture, intensity and grain. Saving an existing name replaces that look while preserving its Shortcuts identity. Applying a look never enables Paper or changes snooze, schedules, power rules or exclusions. Removing a custom paper also removes its favorites and saved looks.

Solar schedules offer **Sunset to sunrise** and **Sunrise to sunset**. Choose a city; lookup uses Apple's geocoding service without device-location permission. Approximate times are calculated locally with NOAA's solar equations in the city's time zone. The city stays fixed when you travel. Missing/invalid cities pause the overlay; polar day/night is handled explicitly and rechecked daily. Clear a city from the city sheet.

**Automatic day/night looks** applies two saved looks either at sunrise/sunset or with macOS light/dark appearance. The solar option uses the same city as solar scheduling; system appearance needs no city. It changes appearance only; off, snooze and every visibility rule retain priority. Missing solar city or look selections leave the manual appearance in place. Choosing a texture or applying a saved look ends automatic switching. Display intensity overrides remain in force through look changes.

**App-specific looks** assigns existing saved looks to applications. An app assignment takes precedence over automatic day/night switching; exclusions and all visibility rules still win. Opening Paper keeps the underlying foreground app. Selecting a texture or applying a look manually disables both automatic switching modes; re-enable them in Settings when wanted.

**Desk profiles** saves up to eight local setups keyed to the exact connected display identities. Save the current texture, lighting, strip, app/schedule/power rules and intensity overrides; reconnecting that setup or launching Paper recalls it. Saving the same setup replaces its profile. Master off, display exclusions, snooze, presentation pause and shortcuts remain global. Edits are saved to a desk only with **Save this setup**. Profiles and app assignments stay local and are not included in library exports.

**Reading strip** leaves a clear horizontal band through the texture and lighting on every enabled display. Toggle it in the menu; configure its height/position in Settings and optionally assign up/down shortcuts. It does not follow the pointer or inspect screen contents. **Desk Lamp** is an optional static warm wash, blended with the same intensity and governed by the same pause rules. Neither effect animates or changes hardware color settings.

**Pause for presentation** in the menu removes overlays until **End presentation pause**, including across relaunches. A timed snooze expiring or toggling Paper does not end this explicit pause. Use it before sharing, capturing or entering protected authorization UI; Paper does not detect meetings or promise capture invisibility.

Global shortcuts can be customized for toggle, 15-minute snooze, next favorite, strip up/down and presentation pause. Optional commands start unassigned. Bindings use physical A–Z keys with Command or Control; conflicts are reported per action without disabling other bindings. Standard menu/app shortcuts may also use a combination, so test your chosen keys in the apps you use.

An optional **low-battery threshold** pauses at or below the chosen percentage while unplugged. Connecting power or rising above it resumes only if the other rules permit. Unknown battery capacity does not trigger this rule. Desktop Macs can leave it off.

Paper allows one instance per user: opening another current-version copy brings the existing Settings forward. Its local lock is released on normal exit or a crash. Quit any pre-0.5 copy before manually trying a new build.

Each display can use the global intensity or its own optional override. Overrides are keyed by display identity and persist when it disconnects. Disable **Custom intensity** to return to the global value. **Only show in selected apps** waits for an included foreground app; an empty list shows no texture. Exclusions still win. Opening Paper's controls preserves the underlying app rule.

**Export library…** saves favorites, saved looks and custom recipes to one versioned JSON backup. **Import library…** merges a backup without changing city, app rules, displays or other settings. Conflicting recipe/look IDs are remapped together, unchanged reimports do not duplicate entries, and invalid or over-capacity merges make no changes. Limits are 1 MB, 50 custom recipes and eight looks after merging. Recipes and their references are stored as one local snapshot. Unreadable settings are retained for recovery and leave Paper off.

Shortcuts exposes **Toggle Paper**, **Set Paper Enabled**, **Snooze Paper**, **Select Paper Texture**, and **Apply Paper Look**. These open Paper and call the same state commands as its controls. Texture and look parameters use stable identities; removed selections fail with a readable error. On newer macOS, running App Intents requires a validated signing identity; use the signed build rather than an ad-hoc build.

Use **Import paper…** to choose one or more Deckle JSON recipes, including `.decklepaper.json` files. Each recipe receives a fresh local identity while preserving its rendering seed. Imports are limited to 1 MB per file and 50 saved papers. Invalid files report an error while valid files still import. Remove an imported paper with its button below the picker. There is no editor or online gallery in this version.

**Help & diagnostics…** previews a bounded, filtered report of app/system versions, broad overlay state and recent event categories. You can save it locally, import a Paper `.ips` crash summary, or explicitly send it to this repository through the existing Dust Wave relay. Matching reports are aggregated; retrying an unconfirmed report keeps the same ID. Raw logs, paths, app names, display IDs, city and recipe contents are excluded. See [privacy](docs/privacy.md) and [support](docs/support.md).

The overlay never captures your screen or changes display gamma. It does not require Accessibility, Input Monitoring or Screen Recording permission. Settings and recipes remain local in the `xyz.dustwave.paper` preferences domain. City lookup sends only the city you enter to Apple's service. Update checks/downloads use GitHub; reviewed report submissions use `crash.dustwave.xyz`. No diagnostic is sent automatically. Pause the effect for screenshots, screen sharing and color-sensitive work; it does not promise to hide itself from capture tools.

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

The exact Platform gitlink includes the desktop support package and separately licensed display test fixture. Initialize submodules when cloning; the source ZIP includes the complete pinned tree.

The Codex Run action calls that same script. `--build-only` stages `dist/Paper.app`; `--logs` streams logs after launch. The script creates an arm64 release binary and an ad-hoc development signature unless `PAPER_SIGNING_IDENTITY` names an installed Developer ID identity. App Intents metadata is extracted into the bundle before signing. Signed updates use the shared Platform Sparkle adapter. Checks run quietly at launch and periodically when enabled; installation requires your action. Use **Check for Updates…** or turn automatic checks off in settings.

From a committed Git checkout, `./script/package.sh` builds the local DMG and source ZIP in `outputs/`. The source ZIP includes the pinned Platform source tree; pin validation itself needs Git metadata. An example import is in `docs/examples/soft-linen.decklepaper.json`.

`./script/package.sh --notarize` uses the installed Developer ID identity, reads the API key and issuer from iCloud Drive's **Apple Auth**, signs/notarizes/staples the app and DMG, and verifies Gatekeeper acceptance. Set `DUSTWAVE_APPLE_AUTH_DIR` to override the credential directory or `PAPER_SIGNING_IDENTITY` if more than one identity is installed. Credentials remain outside the repository and artifacts. Notarization receipts retain submission IDs for retry; no public upload or release is performed.

The [native display suite](Tests/native_display/README.md) uses Platform's shared test-only virtual-monitor fixture, with Paper-specific geometry, focus, exclusion and hot-plug checks. Helpers are never bundled with the app. This does not qualify physical HDR/cable/wake behavior or every supported OS.

The renderer and recipe model are pinned, attributed Deckle sources. Record supplies the login adapter, shortcut-registration pattern and display-placement lessons. The Platform gitlink supplies pin/documentation/integrity tools and its separate desktop update/diagnostic package, without importing its speech or AI runtime. See [upstream review](docs/upstream-review.md), [third-party notices](THIRD_PARTY_NOTICES.md), and [testing evidence](docs/testing.md).

The application is MIT-licensed. The separate native display test tooling is GPL-3.0, retaining OwlSwitch's license. This is an independent app, not a Paperman or Deckle release.

For contribution and release steps, see [CONTRIBUTING](CONTRIBUTING.md), [release workflow](docs/releasing.md), and [roadmap](docs/roadmap.md). Versions through 0.3.0 need one manual installation of an updater-enabled build.
