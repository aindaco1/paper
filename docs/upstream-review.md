# Upstream review — September 24, 2026

Reviewed the live [Deckle issues](https://github.com/YellowFoxH4XOR/deckle/issues) and [pull requests](https://github.com/YellowFoxH4XOR/deckle/pulls) through GitHub's API, including the relevant proposed patches. The live API showed eight open issues and fourteen open PRs. Cached HTML still showed issue 27 as open; the API confirms it is closed. Open proposals are not treated as merged or tested upstream changes.

Paper uses Deckle revision `cb4eb09dc117bb046c3ca83b782c5a9ed53dfd91`. It vendors the renderer and preset file unchanged and extracts only CustomPaper plus its preset conversion from PaperMill. A manifest records exact file hashes. Record is referenced at `3f687d9131f13e3bfc309653a187f97acf911bc2`; its login adapter has one default-initialization adaptation for Swift 5 language mode. Platform is pinned at `0affb6c5652611b87947bd87762d8aa17d35ea32`, using test-core 0.3.0 and release-core 0.4.0 for tooling.

| Issue or PR | Decision in Paper |
| --- | --- |
| [Issue 19: scheduling](https://github.com/YellowFoxH4XOR/deckle/issues/19) | Implement a local-time window without location access, explicit precedence and DST tests. |
| [Issue 17: battery/Low Power Mode](https://github.com/YellowFoxH4XOR/deckle/issues/17) | Implement both optional rules using system notifications and a power-source callback. |
| [Issue 18: custom snooze](https://github.com/YellowFoxH4XOR/deckle/issues/18) | Keep 15/30/60-minute choices for this simple version. |
| [Issue 27](https://github.com/YellowFoxH4XOR/deckle/issues/27), [PR 34](https://github.com/YellowFoxH4XOR/deckle/pull/34) | Use a regular, scrollable settings window and a small NSMenu. No expanding MenuBarExtra popover to resize. |
| [PR 43: file failures](https://github.com/YellowFoxH4XOR/deckle/pull/43) | Report import errors, retain successful entries, assign fresh identities and test partial imports. No export/editor scope. |
| [PR 44: visibility coverage](https://github.com/YellowFoxH4XOR/deckle/pull/44) | Add explicit, value-only policy tests. Paper's own settings do not bypass the underlying foreground-app exclusion. |
| [PR 46: persistence failures](https://github.com/YellowFoxH4XOR/deckle/pull/46) | Preserve unreadable data under a distinct backup key and surface recovery. Centralize typed persistence. |
| [PR 41: login approval](https://github.com/YellowFoxH4XOR/deckle/pull/41) | Use Record's tested service adapter, show failures, and offer the Login Items approval link. |
| [PR 49: thumbnail rendering](https://github.com/YellowFoxH4XOR/deckle/pull/49) | Render the sample in a keyed task with the existing tile cache; never synthesize from body. No Paper Mill/cache API fork needed. |
| [PRs 39](https://github.com/YellowFoxH4XOR/deckle/pull/39), [47](https://github.com/YellowFoxH4XOR/deckle/pull/47), [48](https://github.com/YellowFoxH4XOR/deckle/pull/48), [50](https://github.com/YellowFoxH4XOR/deckle/pull/50): accessibility | Name controls and removal actions, announce intensity as a percentage, hide decorative icons, and expose actual menu-bar state. |
| [PR 42: repeated search work](https://github.com/YellowFoxH4XOR/deckle/pull/42) | No searchable/gallery UI in this scope; use a single compact picker. |
| [PR 45: community downloads](https://github.com/YellowFoxH4XOR/deckle/pull/45) | No online gallery or download client. Import user-selected local recipes. |
| [PR 38: URL diagnostics](https://github.com/YellowFoxH4XOR/deckle/pull/38) | No URL automation in this version. |
| [PRs 40](https://github.com/YellowFoxH4XOR/deckle/pull/40), [51](https://github.com/YellowFoxH4XOR/deckle/pull/51): updater errors/blocking | Do not include Deckle's custom updater. A future release can adapt Record's signed Sparkle flow once Paper has a release identity/feed. |
| Issues 6, 14, 15, 16 | Windows, localization and community features are outside this first macOS build. Existing renderer supports imported recipes. |
| Issue 52 | Promotional invitation; unrelated to implementation. |

No PR was cherry-picked wholesale and no upstream issue or PR was modified. The source manifest and retained tests make future upstream refreshes reviewable. No Record or Platform source was changed for this first consumer.

