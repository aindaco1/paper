# Upstream review — September 24, 2026

Reviewed the live [Deckle issues](https://github.com/YellowFoxH4XOR/deckle/issues) and [pull requests](https://github.com/YellowFoxH4XOR/deckle/pulls) through GitHub's API, including the relevant proposed patches. The live API showed eight open issues and fourteen open PRs. Cached HTML still showed issue 27 as open; the API confirms it is closed. Open proposals are not treated as merged or tested upstream changes.

Paper uses Deckle revision `cb4eb09dc117bb046c3ca83b782c5a9ed53dfd91`. It vendors the renderer and preset file unchanged and extracts only CustomPaper plus its preset conversion from PaperMill. A manifest records exact file hashes. Record is referenced at `3f687d9131f13e3bfc309653a187f97acf911bc2`; its login adapter has one default-initialization adaptation for Swift 5 language mode. The initial review used Platform `0affb6c5652611b87947bd87762d8aa17d35ea32`. Paper 0.4.0 pins published revision `2054aaec3264393390577c70cb0a084a256a835c`, with test-core 0.3.1, release-core 0.4.0, the test-only display fixture 0.1.0, and the separate desktop update/diagnostics package 0.1.0. The latter reuses Record and Auto Subtitle patterns without linking the speech/AI package.

| Issue or PR | Decision in Paper |
| --- | --- |
| [Issue 19: scheduling](https://github.com/YellowFoxH4XOR/deckle/issues/19) | Implement a local-time window without location access, explicit precedence and DST tests. |
| [Issue 17: battery/Low Power Mode](https://github.com/YellowFoxH4XOR/deckle/issues/17) | Implement both optional rules using system notifications and a power-source callback. |
| [Issue 18: custom snooze](https://github.com/YellowFoxH4XOR/deckle/issues/18) | Addressed in 0.1.1: 15/30/60/120 minutes, custom whole minutes (1–1,440), and next-day 6 AM. The menu bar and Shortcuts share the deadline policy; DST, persistence and pause precedence are tested. |
| [Issue 27](https://github.com/YellowFoxH4XOR/deckle/issues/27), [PR 34](https://github.com/YellowFoxH4XOR/deckle/pull/34) | Use a regular, scrollable settings window and a small NSMenu. No expanding MenuBarExtra popover to resize. |
| [PR 43: file failures](https://github.com/YellowFoxH4XOR/deckle/pull/43) | Report import errors, retain successful entries, assign fresh identities and test partial imports. In 0.1.1, decode failures explain that a complete, supported Deckle JSON recipe is required. No export/editor scope. |
| [PR 44: visibility coverage](https://github.com/YellowFoxH4XOR/deckle/pull/44) | Add explicit, value-only policy tests. Paper's own settings do not bypass the underlying foreground-app exclusion. |
| [PR 46: persistence failures](https://github.com/YellowFoxH4XOR/deckle/pull/46) | Preserve unreadable data under a distinct backup key and surface recovery. Centralize typed persistence. |
| [PR 41: login approval](https://github.com/YellowFoxH4XOR/deckle/pull/41) | Use Record's tested service adapter, show failures, and offer the Login Items approval link. In 0.1.1, an unavailable service also disables the toggle and explains why. |
| [PR 49: thumbnail rendering](https://github.com/YellowFoxH4XOR/deckle/pull/49) | Render the sample in a keyed task with the existing tile cache; never synthesize from body. No Paper Mill/cache API fork needed. |
| [PRs 39](https://github.com/YellowFoxH4XOR/deckle/pull/39), [47](https://github.com/YellowFoxH4XOR/deckle/pull/47), [48](https://github.com/YellowFoxH4XOR/deckle/pull/48), [50](https://github.com/YellowFoxH4XOR/deckle/pull/50): accessibility | Name controls and removal actions, announce intensity as a percentage, hide decorative icons, and expose actual menu-bar state. In 0.1.1 the visible and accessible percentage share a formatter, fixing floating-point truncation such as 29% being read as 28%. |
| [PR 42: repeated search work](https://github.com/YellowFoxH4XOR/deckle/pull/42) | No searchable/gallery UI in this scope; use a single compact picker. |
| [PR 45: community downloads](https://github.com/YellowFoxH4XOR/deckle/pull/45) | No online gallery or download client. Import user-selected local recipes. |
| [PR 38: URL diagnostics](https://github.com/YellowFoxH4XOR/deckle/pull/38) | No URL automation in this version. |
| [PRs 40](https://github.com/YellowFoxH4XOR/deckle/pull/40), [51](https://github.com/YellowFoxH4XOR/deckle/pull/51): updater errors/blocking | Do not include Deckle's custom updater. A future release can adapt Record's signed Sparkle flow once Paper has a release identity/feed. |
| [Issue 15: built-in textures](https://github.com/YellowFoxH4XOR/deckle/issues/15) | 0.1.2 exposes all 26 textures from the unchanged pinned catalog, with Soft Wove as the default for new installations. |
| Issues 6, 14, 16 | Windows, localization and community features are outside this first macOS build. Existing renderer supports imported recipes. |
| Issue 52 | Promotional invitation; unrelated to implementation. |

No PR was cherry-picked wholesale and no upstream issue or PR was modified. The source manifest and retained tests make future upstream refreshes reviewable. No Record or Platform source was changed for this first consumer.

The 0.1.1 follow-up refreshed the live issues/PRs and confirmed that upstream HEAD still matches the pinned revision. No public per-texture usage, voting or download ranking was found in the [preset catalog](https://github.com/YellowFoxH4XOR/deckle/blob/cb4eb09dc117bb046c3ca83b782c5a9ed53dfd91/Sources/Deckle/TexturePreset.swift) or [community index](https://raw.githubusercontent.com/YellowFoxH4XOR/deckle-papers/main/index.json). The latter contains three entries with name, author, description and file only. Paper therefore bundles the seven material papers immediately after Soft Wove in the catalog: Rice Paper, Laid Cotton, Newsprint, Cold Press, Artist Canvas, Foxed Amber and Bookcloth. These are catalog selections, not a claimed popularity ranking. All original three choices and existing selections remain available.

The follow-up also fixes the local build workflow: it stops both project-owned app copies before rebuilding, checks the exact newly launched executable, and derives archive versions from Info.plist. This avoids stacked development overlays and stale version labels; it does not change the upstream renderer or add runtime dependencies.

Version 0.1.2 replaces the separate list of ten texture IDs with Deckle's complete pinned catalog. Soft Wove (`classic-matte`) appears first and is the default for new installations, unreadable settings, and unavailable or removed selections. Valid saved choices remain unchanged. No renderer, recipe format or vendor file changed.

Roadmap suggestions recorded for version 0.1.2:

- Favorites or a few saved combinations of texture, intensity and grain would make the larger catalog easier to use. Deckle's existing desk setups provide a reference; keep Paper's version small.
- Native Shortcuts actions for toggle, snooze and texture selection could reuse Paper's state commands without a new automation server or URL parser.
- Actual sunrise/sunset scheduling remains on the [Deckle roadmap](https://github.com/YellowFoxH4XOR/deckle#roadmap) and [issue 19](https://github.com/YellowFoxH4XOR/deckle/issues/19). Paper already has daily fixed-time scheduling; solar times would require an explicit city or optional location choice.

Before public distribution, prioritize Developer ID signing, notarization and the hardware/OS acceptance checks recorded in `testing.md`. Battery rules and custom snooze are already implemented; a community browser or recipe editor can wait.

Version 0.2.0 implements those requested follow-ups: favorites, up to eight saved appearance combinations, five native App Intents (including saved-look selection), and city-based sunrise/sunset schedules. The intents use the same state commands as the controls. Solar policy stays in PaperCore; the narrow CoreLocation adapter only resolves an explicitly entered city. NOAA's approximate solar equations run locally and handle polar days/nights, city time zones, and daily reevaluation. Existing fixed-time settings migrate without resetting the user's preferences.

Signing/notarization now uses the installed Developer ID identity and API credentials read directly from Apple Auth. The app and DMG have separate acceptance/stapling checks and receipts. No credentials are copied or hard-coded, no updater was added, and no public release is published by these scripts.

The Platform pin advances to `6bb9854149203ee71445bf150c4ba86fac607d04` for `tools/macos-display` 0.1.0. This separate GPL-3.0 test fixture retains OwlSwitch's license and supports AppKit enumeration or an injected Qt enumerator. Paper's executable contains none of its test helpers/private APIs. The OwlSwitch adapter migration is kept in an isolated local branch. After earlier desktop focus interference, its final idle-desktop run passed all 18 native cases against the supplied app, with exact display restoration. Fixture smoke and oracle tests also passed; see `testing.md`. Physical hardware and public release qualification remain separate.
