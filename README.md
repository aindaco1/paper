# Paper

A small, free, open-source paper-texture overlay for Apple Silicon Macs running macOS 13 or later.

Paper has three built-in textures, intensity and grain controls, an instant comparison, snooze, display selection, app exclusions, a daily schedule, battery/Low Power Mode pause, and Deckle-compatible JSON imports. The menu-bar shortcut is **Shift–Option–Command–P**. Launch at login is optional.

Open Paper to show settings. Close the settings window to leave the effect running. Use its menu-bar icon to toggle, snooze or quit. Comparison ends when settings close. Snoozing, excluded apps/displays, battery rules and schedules never override the master off switch.

The schedule uses the Mac's local time, supports overnight windows, includes the start time and excludes the end time. Equal start/end times mean all day. Nonexistent daylight-saving times advance to the next valid time; repeated times use the first occurrence. A one-shot timer and wake/timezone notifications update the effect without polling.

Use **Import paper…** to choose one or more Deckle JSON recipes, including `.decklepaper.json` files. Each recipe receives a fresh local identity while preserving its rendering seed. Imports are limited to 1 MB per file and 50 saved papers. Invalid files report an error while valid files still import. Remove an imported paper with its button below the picker. There is no editor or online gallery in this version.

The overlay never captures your screen or changes display gamma. It does not require Accessibility, Input Monitoring or Screen Recording permission. Settings and recipes remain local in the `xyz.dustwave.paper` preferences domain. Pause the effect for screenshots, screen sharing and color-sensitive work; it does not promise to hide itself from capture tools.

To build a source ZIP, use Xcode's Swift toolchain:

```sh
swift test
./script/build_and_run.sh --verify
```

In a Git checkout, also initialize and validate the Platform pin with Node 20.9+:

```sh
git submodule update --init
node script/validate.mjs
```

The Codex Run action calls that same script. `--build-only` stages `dist/Paper.app`; `--logs` streams logs after launch. The script creates an arm64 release binary and an ad-hoc development signature. This first build has no automatic updater or network client. A public release needs its own Developer ID signing/notarization and a configured signed Sparkle feed; it must not reuse Record's app identity or keys.

From a committed Git checkout, `./script/package.sh` builds the local DMG and source ZIP in `outputs/`. The source ZIP includes the pinned Platform source tree; pin validation itself needs Git metadata. An example import is in `docs/examples/soft-linen.decklepaper.json`.

The renderer and recipe model are pinned, attributed Deckle sources. Record supplies the login adapter, shortcut-registration pattern and display-placement lessons. The Platform gitlink supplies the existing pin/documentation/integrity tools without importing its unrelated speech or AI runtime. See [upstream review](docs/upstream-review.md), [third-party notices](THIRD_PARTY_NOTICES.md), and [testing evidence](docs/testing.md).

MIT-licensed. This is an independent app, not a Paperman or Deckle release.
